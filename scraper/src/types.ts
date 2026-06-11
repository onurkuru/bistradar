// Normalized shapes the iOS app consumes. Kept deliberately flat and stable —
// the app reads these straight off a static host, so the contract must not churn.

export interface IPO {
  ticker: string;           // BIST code once assigned, else ""
  company: string;
  status: "upcoming" | "collecting" | "listed" | "draft";
  subscriptionStart?: string; // ISO date — talep toplama başlangıç
  subscriptionEnd?: string;   // ISO date — talep toplama bitiş
  listingDate?: string;       // ISO date — ilk işlem günü
  priceMin?: number;
  priceMax?: number;
  priceFixed?: number;        // fixed-price offerings
  lotCount?: number;
  method?: string;            // "Sabit Fiyat", "Fiyat Aralığı", "Talep Toplama"
  market?: string;            // "Yıldız Pazar" vb.
  intermediary?: string;      // aracı kurum
  sourceUrl: string;
  disclosureId?: string;
  updatedAt: string;          // ISO timestamp of this record's last sync
}

export interface Dividend {
  ticker: string;
  company?: string;
  exDate: string;             // ISO date — hak kullanım (ex-dividend) tarihi
  paymentDate?: string;       // ISO date — ödeme tarihi
  grossPerShare?: number;     // brüt / pay
  netPerShare?: number;       // net / pay
  yieldPct?: number;          // temettü verimi %
  payoutRatioPct?: number;    // dağıtım oranı %
  totalAmount?: number;       // dağıtılan toplam (TL)
  source: "kap" | "isyatirim";
  sourceUrl: string;
  announced: boolean;         // true = future/announced, false = realized history
  updatedAt: string;
}

export interface Feed {
  generatedAt: string;
  ipos: IPO[];
  dividends: Dividend[];
}

// --- parsing helpers for Turkish-formatted numbers/dates ---

/** "3.088.926.647" / "5,2669" -> number. TR uses '.' thousands, ',' decimal. */
export function trNumber(raw: string | undefined | null): number | undefined {
  if (!raw) return undefined;
  const cleaned = raw.trim().replace(/\./g, "").replace(",", ".").replace(/[^0-9.\-]/g, "");
  if (cleaned === "" || cleaned === "-") return undefined;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : undefined;
}

/** "07.04.2026" or "13-14-15 Mayıs 2026" handled elsewhere; this does dd.mm.yyyy. */
export function trDateToISO(raw: string | undefined | null): string | undefined {
  if (!raw) return undefined;
  const m = raw.trim().match(/(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})/);
  if (!m) return undefined;
  const [, d, mo, y] = m;
  return `${y}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
}
