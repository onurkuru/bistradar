// Best-effort extraction of IPO details (subscription dates, price, listing date)
// from the free-text narrative of a KAP "halka arz / talep toplama" disclosure.
// KAP embeds these in prose + a table, not clean label/value pairs, so we use
// tolerant Turkish-language regexes. Every field is optional — when a pattern
// doesn't match we leave it undefined rather than guess.
import { trNumber, trDateToISO } from "../types.js";

export interface IpoDetail {
  subscriptionStart?: string;
  subscriptionEnd?: string;
  listingDate?: string;
  priceFixed?: number;
  priceMin?: number;
  priceMax?: number;
  lotCount?: number;
  method?: string;
}

const DATE = /(\d{1,2}[.\/]\d{1,2}[.\/]\d{4})/;
const DATE_G = /(\d{1,2}[.\/]\d{1,2}[.\/]\d{4})/g;
const NUM = /([\d.]+,\d+|\d{1,3}(?:\.\d{3})+|\d+)/;

function near(text: string, anchor: RegExp, after = 120, before = 0): string | undefined {
  const m = text.match(anchor);
  if (!m || m.index === undefined) return undefined;
  return text.slice(Math.max(0, m.index - before), m.index + after);
}

export function parseIpoDetail(text: string): IpoDetail {
  const t = text.replace(/\s+/g, " ");
  const out: IpoDetail = {};

  // --- Price range: "X TL - Y TL" with a "fiyat" cue nearby ---
  const rangeM =
    t.match(new RegExp(`fiyat\\s*aralığı[^\\d]{0,20}${NUM.source}\\s*(?:TL|₺)?\\s*(?:[-–]|ile)\\s*${NUM.source}`, "i")) ||
    t.match(new RegExp(`${NUM.source}\\s*(?:TL|₺)\\s*[-–]\\s*${NUM.source}\\s*(?:TL|₺)[^.]{0,40}fiyat`, "i"));
  if (rangeM) {
    const lo = trNumber(rangeM[1]);
    const hi = trNumber(rangeM[2]);
    if (lo && hi && lo <= hi) { out.priceMin = lo; out.priceMax = hi; }
  }

  // --- Fixed price: "(satış|halka arz) fiyatı ... X TL" ---
  if (out.priceMin === undefined) {
    const fixedM =
      t.match(new RegExp(`(?:satış|halka\\s*arz|pay(?:ı|ın)?(?:\\s*satış)?)\\s*fiyatı[^\\d]{0,25}${NUM.source}\\s*(?:TL|₺)`, "i")) ||
      t.match(new RegExp(`${NUM.source}\\s*(?:TL|₺)\\s*olmak üzere`, "i"));
    const price = trNumber(fixedM?.[1]);
    // sanity: IPO share prices are realistically < 10,000 TL
    if (price !== undefined && price > 0 && price < 10000) out.priceFixed = price;
  }

  // --- Subscription window: dates near "talep toplama" ---
  const ttChunk = near(t, /talep toplama/i, 160);
  if (ttChunk) {
    const dates = [...ttChunk.matchAll(DATE_G)].map((m) => trDateToISO(m[1])).filter(Boolean) as string[];
    if (dates[0]) out.subscriptionStart = dates[0];
    if (dates[1]) out.subscriptionEnd = dates[1];
  }

  // --- Listing date: "DATE tarihinde ... işlem görmeye" or "işlem görmeye ... DATE" ---
  const listM =
    t.match(/(\d{1,2}[.\/]\d{1,2}[.\/]\d{4})\s*tarihinde[^.]{0,60}?(?:borsa|işlem görme)/i) ||
    t.match(/(?:işlem görmeye baş\w*|borsada işlem görmeye|ilk işlem günü)[^.]{0,60}?(\d{1,2}[.\/]\d{1,2}[.\/]\d{4})/i);
  if (listM) out.listingDate = trDateToISO(listM[1]);

  // --- Lot / nominal size: largest "X adet|TL nominal" (skip the 1 TL par value) ---
  const lots = [...t.matchAll(new RegExp(`${NUM.source}\\s*(?:adet|TL nominal|nominal değerli)`, "ig"))]
    .map((m) => trNumber(m[1]) ?? 0)
    .filter((n) => n > 1000);
  if (lots.length) out.lotCount = Math.max(...lots);

  // --- Method ---
  if (/sabit fiyat/i.test(t)) out.method = "Sabit Fiyat";
  else if (/fiyat aralığı/i.test(t)) out.method = "Fiyat Aralığı";
  else if (/hızlandırılmış talep/i.test(t)) out.method = "Hızlandırılmış Talep Toplama";
  else if (/talep toplama/i.test(t)) out.method = "Talep Toplama";

  return out;
}

/** Derive a display status from the parsed dates relative to `today` (ISO). */
export function deriveStatus(detail: IpoDetail, todayISO: string): "upcoming" | "collecting" | "listed" | "draft" {
  if (detail.listingDate && detail.listingDate <= todayISO) return "listed";
  if (detail.subscriptionStart && detail.subscriptionEnd) {
    if (todayISO >= detail.subscriptionStart && todayISO <= detail.subscriptionEnd) return "collecting";
    if (todayISO < detail.subscriptionStart) return "upcoming";
  }
  if (detail.subscriptionStart && todayISO <= detail.subscriptionStart) return "upcoming";
  return detail.subscriptionStart || detail.priceFixed || detail.priceMin ? "upcoming" : "draft";
}
