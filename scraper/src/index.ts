// Orchestrator: pull official KAP disclosures for a recent window, turn dividend
// disclosures into structured records (enriched via İş Yatırım), collect IPO
// disclosures, then merge into the persisted feed.json the iOS app reads.
//
// Run: npx tsx src/index.ts [windowDays]
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  fetchDisclosures,
  isDividendDisclosure,
  isIpoDisclosure,
  kapDetailUrl,
  type KapDisclosure,
} from "./sources/kap.js";
import { fetchDividends } from "./sources/isyatirim.js";
import { Feed, IPO, Dividend, trDateToISO } from "./types.js";

const __dir = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(__dir, "../../data/feed.json");

const WINDOW_DAYS = Number(process.argv[2] ?? 4);

function isoDaysAgo(days: number): string {
  const ms = Date.now() - days * 86_400_000;
  return new Date(ms).toISOString().slice(0, 10);
}

function kapDateToISO(publishDate: string): string | undefined {
  // "10.06.2026 19:19:05" -> "2026-06-10"
  return trDateToISO(publishDate.split(" ")[0]);
}

async function loadFeed(): Promise<Feed> {
  try {
    return JSON.parse(await readFile(OUT, "utf8")) as Feed;
  } catch {
    return { generatedAt: "", ipos: [], dividends: [] };
  }
}

/** Map a KAP dividend disclosure to structured records via İş Yatırım. */
async function buildDividends(disclosures: KapDisclosure[], now: string): Promise<Dividend[]> {
  const tickers = new Set<string>();
  for (const d of disclosures) {
    for (const code of (d.stockCodes ?? "").split(",").map((s) => s.trim()).filter(Boolean)) {
      tickers.add(code);
    }
  }

  const out: Dividend[] = [];
  for (const ticker of tickers) {
    try {
      const all = await fetchDividends(ticker);
      // Keep the most recent (announced/future or just-passed) entry per ticker.
      const recent = all
        .filter((d) => new Date(d.exDate) >= new Date(isoDaysAgo(120)))
        .sort((a, b) => b.exDate.localeCompare(a.exDate));
      for (const d of recent) out.push(d);
      await sleep(400); // be polite to İş Yatırım
    } catch (e) {
      console.warn(`  ! İş Yatırım dividends failed for ${ticker}: ${(e as Error).message}`);
    }
  }
  return out;
}

function buildIpos(disclosures: KapDisclosure[], now: string): IPO[] {
  return disclosures.map((d): IPO => {
    const code = (d.stockCodes ?? "").split(",")[0]?.trim() ?? "";
    return {
      ticker: code,
      company: d.kapTitle,
      status: "upcoming", // refined later from detail page (subscription dates)
      method: undefined,
      sourceUrl: kapDetailUrl(d.disclosureIndex),
      disclosureId: String(d.disclosureIndex),
      updatedAt: now,
    };
  });
}

function mergeDividends(existing: Dividend[], fresh: Dividend[]): Dividend[] {
  const byKey = new Map<string, Dividend>();
  for (const d of [...existing, ...fresh]) byKey.set(`${d.ticker}|${d.exDate}`, d);
  return [...byKey.values()].sort((a, b) => b.exDate.localeCompare(a.exDate));
}

function mergeIpos(existing: IPO[], fresh: IPO[]): IPO[] {
  const byKey = new Map<string, IPO>();
  for (const i of existing) byKey.set(i.disclosureId ?? `${i.company}`, i);
  for (const i of fresh) byKey.set(i.disclosureId ?? `${i.company}`, i); // fresh wins
  return [...byKey.values()];
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const now = new Date().toISOString();
  const from = isoDaysAgo(WINDOW_DAYS);
  const to = isoDaysAgo(0);
  console.log(`KAP disclosures ${from} → ${to} ...`);

  const all = await fetchDisclosures(from, to);
  console.log(`  ${all.length} disclosures fetched`);

  const divDisc = all.filter(isDividendDisclosure);
  const ipoDisc = all.filter(isIpoDisclosure);
  console.log(`  ${divDisc.length} dividend, ${ipoDisc.length} IPO disclosures`);

  const freshDividends = await buildDividends(divDisc, now);
  const freshIpos = buildIpos(ipoDisc, now);
  console.log(`  built ${freshDividends.length} dividend records, ${freshIpos.length} IPO records`);

  const prev = await loadFeed();
  const feed: Feed = {
    generatedAt: now,
    dividends: mergeDividends(prev.dividends, freshDividends),
    ipos: mergeIpos(prev.ipos, freshIpos),
  };

  await mkdir(dirname(OUT), { recursive: true });
  await writeFile(OUT, JSON.stringify(feed, null, 2));
  console.log(`Wrote ${OUT}: ${feed.dividends.length} dividends, ${feed.ipos.length} IPOs total`);
}

main().catch((e) => {
  console.error("sync failed:", e);
  process.exit(1);
});
