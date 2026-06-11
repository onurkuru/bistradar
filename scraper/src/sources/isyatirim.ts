// İş Yatırım (a licensed brokerage — broker-grade source) for per-stock dividend
// history and prices. The dividend JSON endpoint is auth-walled (401), but the
// public company-card page renders the full dividend table server-side, so we
// parse that HTML. No auth, no key.
import * as cheerio from "cheerio";
import { Dividend, trNumber, trDateToISO } from "../types.js";

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

const CARD_URL = (ticker: string) =>
  `https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/sirket-karti.aspx?hisse=${encodeURIComponent(ticker)}`;

const PRICE_URL = (ticker: string, start: string, end: string) =>
  `https://www.isyatirim.com.tr/_layouts/15/IsYatirim.Website/Common/Data.aspx/HisseTekil` +
  `?hisse=${encodeURIComponent(ticker)}&startdate=${start}&enddate=${end}`;

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { "User-Agent": UA, Accept: "text/html,application/json" },
  });
  if (!res.ok) throw new Error(`${url} -> ${res.status}`);
  return res.text();
}

/**
 * Parse the `temettugercekvarrow` table from the company card.
 * Columns (observed): ticker, date, yield%, net/share, gross/share, ?, total, payoutRatio%.
 */
export async function fetchDividends(ticker: string): Promise<Dividend[]> {
  const html = await fetchText(CARD_URL(ticker));
  const $ = cheerio.load(html);
  const now = new Date().toISOString();
  const out: Dividend[] = [];
  const seen = new Set<string>();

  $("tr[class*='temettugercekvarrow']").each((_, el) => {
    const cells = $(el)
      .find("td")
      .map((__, td) => $(td).text().trim())
      .get();
    if (cells.length < 8) return;
    // Columns: ticker, date, yield%, grossTL/share, gross%, net%, totalTL, payoutRatio%.
    // Net TL/share = net% / 100 (1 TL par). Cross-checked: GARAN 2026 → gross 5.2669, net 4.4769.
    const [code, date, yieldPct, grossTL, , netPct, total, payout] = cells;
    const exISO = trDateToISO(date);
    if (!exISO) return;
    const key = `${code}|${exISO}`;
    if (seen.has(key)) return; // page repeats the table twice
    seen.add(key);

    const netRate = trNumber(netPct);
    out.push({
      ticker: code || ticker,
      exDate: exISO,
      grossPerShare: trNumber(grossTL),
      netPerShare: netRate === undefined ? undefined : netRate / 100,
      yieldPct: trNumber(yieldPct),
      payoutRatioPct: payout === "A/D" ? undefined : trNumber(payout),
      totalAmount: trNumber(total),
      source: "isyatirim",
      sourceUrl: CARD_URL(ticker),
      announced: new Date(exISO) > new Date(),
      updatedAt: now,
    });
  });

  return out;
}

export interface PricePoint {
  date: string;
  close: number;
}

/** Daily closes; used to enrich a stock detail screen. Auth-free JSON endpoint. */
export async function fetchPrices(ticker: string, start: string, end: string): Promise<PricePoint[]> {
  const txt = await fetchText(PRICE_URL(ticker, start, end));
  const json = JSON.parse(txt) as {
    value?: { HGDG_TARIH: string; HGDG_KAPANIS: number }[];
  };
  return (json.value ?? []).map((v) => ({
    date: trDateToISO(v.HGDG_TARIH) ?? v.HGDG_TARIH,
    close: v.HGDG_KAPANIS,
  }));
}
