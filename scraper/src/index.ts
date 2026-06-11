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
  fetchDetailTexts,
  isDividendDisclosure,
  isIpoDisclosure,
  kapDetailUrl,
  type KapDisclosure,
} from "./sources/kap.js";
import { fetchDividends, fetchPrices } from "./sources/isyatirim.js";
import { parseIpoDetail, deriveStatus } from "./sources/parseIpo.js";
import { Feed, IPO, Dividend, StockInfo, PricePoint, trDateToISO } from "./types.js";

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

function ddmmFromISO(iso: string): string {
  const [y, m, d] = iso.split("-");
  return `${d}-${m}-${y}`;
}

/**
 * For each ticker that announced a dividend, pull from İş Yatırım:
 *  - dividend history (kept ~4 years so the detail screen shows past payouts), and
 *  - a recent daily-close series for the price chart + last price/change.
 */
async function buildDividendsAndStocks(
  disclosures: KapDisclosure[],
  now: string
): Promise<{ dividends: Dividend[]; stocks: Record<string, StockInfo> }> {
  const tickers = new Set<string>();
  for (const d of disclosures) {
    for (const code of (d.stockCodes ?? "").split(",").map((s) => s.trim()).filter(Boolean)) {
      tickers.add(code);
    }
  }

  const dividends: Dividend[] = [];
  const stocks: Record<string, StockInfo> = {};
  const historyCutoff = isoDaysAgo(365 * 4);
  const priceFrom = ddmmFromISO(isoDaysAgo(180));
  const priceTo = ddmmFromISO(isoDaysAgo(0));

  for (const ticker of tickers) {
    try {
      const all = await fetchDividends(ticker);
      for (const d of all.filter((x) => x.exDate >= historyCutoff)) dividends.push(d);
      await sleep(300);

      const series = await fetchPrices(ticker, priceFrom, priceTo);
      const points: PricePoint[] = series
        .filter((p) => Number.isFinite(p.close) && p.close > 0)
        .map((p) => ({ d: p.date, c: Number(p.close.toFixed(4)) }));
      const last = points.at(-1)?.c;
      const prev = points.at(-2)?.c;
      stocks[ticker] = {
        ticker,
        lastClose: last,
        changePct: last && prev ? Number((((last - prev) / prev) * 100).toFixed(2)) : undefined,
        prices: points,
      };
      await sleep(300);
    } catch (e) {
      console.warn(`  ! İş Yatırım failed for ${ticker}: ${(e as Error).message}`);
    }
  }
  return { dividends, stocks };
}

async function buildIpos(disclosures: KapDisclosure[], now: string): Promise<IPO[]> {
  const todayISO = isoDaysAgo(0);
  // One entry per company (KAP returns most-recent first), capped to keep the
  // sync quick. Each is enriched from its KAP detail page.
  const byCompany = new Map<string, KapDisclosure>();
  for (const d of disclosures) {
    const key = (d.stockCodes ?? "").split(",")[0]?.trim() || d.kapTitle;
    if (!byCompany.has(key)) byCompany.set(key, d);
  }
  const recent = [...byCompany.values()].slice(0, 14);
  const details = await fetchDetailTexts(recent.map((d) => d.disclosureIndex));

  const mapped = recent.map((d): IPO => {
    const code = (d.stockCodes ?? "").split(",")[0]?.trim() ?? "";
    const parsed = parseIpoDetail(details.get(d.disclosureIndex) ?? "");
    return {
      ticker: code,
      company: d.kapTitle,
      status: deriveStatus(parsed, todayISO),
      subscriptionStart: parsed.subscriptionStart,
      subscriptionEnd: parsed.subscriptionEnd,
      listingDate: parsed.listingDate,
      priceFixed: parsed.priceFixed,
      priceMin: parsed.priceMin,
      priceMax: parsed.priceMax,
      lotCount: parsed.lotCount,
      method: parsed.method,
      sourceUrl: kapDetailUrl(d.disclosureIndex),
      disclosureId: String(d.disclosureIndex),
      updatedAt: now,
    };
  });

  // Precision filter: keep only IPO events we could enrich with actionable data
  // (subscription window, price, or listing date). Drops underwriter (YK) noise
  // that merely mentions "halka arz" without being a real offering.
  return mapped.filter(
    (i) => i.subscriptionStart || i.priceFixed || i.priceMin || i.listingDate
  );
}

function mergeDividends(existing: Dividend[], fresh: Dividend[]): Dividend[] {
  const byKey = new Map<string, Dividend>();
  for (const d of [...existing, ...fresh]) byKey.set(`${d.ticker}|${d.exDate}`, d);
  return [...byKey.values()].sort((a, b) => b.exDate.localeCompare(a.exDate));
}

function mergeIpos(existing: IPO[], fresh: IPO[]): IPO[] {
  // Key by company so a company has a single, latest IPO entry.
  const key = (i: IPO) => (i.ticker || i.company);
  const freshKeys = new Set(fresh.map(key));
  const cutoff = isoDaysAgo(45); // drop stale entries no longer disclosed
  const byKey = new Map<string, IPO>();
  for (const i of existing) {
    if (freshKeys.has(key(i))) continue;              // will be replaced by fresh
    if ((i.updatedAt.slice(0, 10)) < cutoff) continue; // expired
    byKey.set(key(i), i);
  }
  for (const i of fresh) byKey.set(key(i), i);
  return [...byKey.values()].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
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

  const { dividends: freshDividends, stocks: freshStocks } = await buildDividendsAndStocks(divDisc, now);
  const freshIpos = await buildIpos(ipoDisc, now);
  console.log(`  built ${freshDividends.length} dividend records, ${Object.keys(freshStocks).length} stocks, ${freshIpos.length} IPO records`);

  const prev = await loadFeed();
  const feed: Feed = {
    generatedAt: now,
    dividends: mergeDividends(prev.dividends, freshDividends),
    ipos: mergeIpos(prev.ipos, freshIpos),
    stocks: { ...prev.stocks, ...freshStocks }, // fresh prices/history win
  };

  await mkdir(dirname(OUT), { recursive: true });
  await writeFile(OUT, JSON.stringify(feed, null, 2));
  console.log(`Wrote ${OUT}: ${feed.dividends.length} dividends, ${Object.keys(feed.stocks ?? {}).length} stocks, ${feed.ipos.length} IPOs total`);
}

main().catch((e) => {
  console.error("sync failed:", e);
  process.exit(1);
});
