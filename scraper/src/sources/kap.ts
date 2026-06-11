// KAP (kap.org.tr) — the OFFICIAL, legally-mandated disclosure platform run by
// MKK. Its public JSON API is closed to plain HTTP (TLS-fingerprint WAF), but
// works from a real browser context. We drive a headless Chromium, then call
// the disclosure-query endpoint via in-browser fetch (correct TLS).
//
// Confirmed endpoint:
//   POST https://www.kap.org.tr/tr/api/disclosure/members/byCriteria
// Response records include: publishDate, kapTitle, disclosureCategory, subject,
// summary, stockCodes, relatedStocks, disclosureIndex.
import { chromium, type Browser } from "playwright";

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

export interface KapDisclosure {
  publishDate: string;
  kapTitle: string;
  disclosureCategory: string;
  disclosureType: string;
  subject: string | null;
  summary: string | null;
  stockCodes: string | null;
  relatedStocks: string | null;
  disclosureIndex: number;
  year: number | null;
}

const DETAIL_URL = (idx: number) => `https://www.kap.org.tr/tr/Bildirim/${idx}`;

// IGS = işlem gören şirketler (listed); YK = yatırım kuruluşları (brokers who
// file IPO/talep-toplama announcements). Querying both covers dividends (IGS)
// and upcoming-IPO disclosures (YK).
const DEFAULT_MEMBER_TYPES = ["IGS", "YK"];

async function openQueryPage(browser: Browser) {
  const ctx = await browser.newContext({ userAgent: UA, locale: "tr-TR" });
  const page = await ctx.newPage();
  await page.goto("https://www.kap.org.tr/tr/bildirim-sorgu", { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForTimeout(1500);
  return page;
}

/** Fetch disclosures between two ISO dates (inclusive) across member types, deduped. */
export async function fetchDisclosures(
  fromISO: string,
  toISO: string,
  memberTypes: string[] = DEFAULT_MEMBER_TYPES
): Promise<KapDisclosure[]> {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await openQueryPage(browser);
    const byIndex = new Map<number, KapDisclosure>();
    for (const memberType of memberTypes) {
      const batch = await queryWindow(page, fromISO, toISO, memberType);
      for (const d of batch) byIndex.set(d.disclosureIndex, d);
    }
    return [...byIndex.values()];
  } finally {
    await browser.close();
  }
}

async function queryWindow(
  page: Awaited<ReturnType<typeof openQueryPage>>,
  fromISO: string,
  toISO: string,
  memberType: string
): Promise<KapDisclosure[]> {
  const payload = JSON.stringify({
    fromDate: fromISO, toDate: toISO, memberType,
    mkkMemberOidList: [], inactiveMkkMemberOidList: [], disclosureClass: "",
    subjectList: [], isLate: "", mainSector: "", sector: "", subSector: "",
    marketOid: "", index: "", bdkReview: "", bdkMemberOidList: [], year: "",
    term: "", ruleType: "", period: "", fromSrc: false, srcCategory: "",
    disclosureIndexList: [],
  });

  return page.evaluate(async (body) => {
    const r = await fetch("/tr/api/disclosure/members/byCriteria", {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json" },
      body,
    });
    if (!r.ok) throw new Error("byCriteria -> " + r.status);
    return r.json();
  }, payload);
}

/** Fetch the rendered narrative text of disclosure detail pages, keyed by index. */
export async function fetchDetailTexts(indices: number[]): Promise<Map<number, string>> {
  const out = new Map<number, string>();
  if (indices.length === 0) return out;
  const browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext({ userAgent: UA, locale: "tr-TR" });
    const page = await ctx.newPage();
    for (const idx of indices) {
      try {
        await page.goto(DETAIL_URL(idx), { waitUntil: "networkidle", timeout: 45000 });
        await page.waitForTimeout(1500);
        const text = await page.locator("main, body").first().innerText().catch(() => "");
        out.set(idx, text);
      } catch {
        // Skip a detail that won't load; the IPO still shows with its KAP link.
      }
    }
    return out;
  } finally {
    await browser.close();
  }
}

// --- classification helpers ---

// Actionable IPO events (talep toplama, izahname, halka arz sonuç, listing).
const IPO_RE = /talep toplama|izahna|halka arz|borsada işlem görme|ilk işlem günü|pay.*halka/i;
// Post-IPO follow-up reports that carry no subscription dates/price — excluded
// so the IPO tab shows only real, actionable offerings.
const IPO_EXCLUDE_RE = /fiyatının belirlenmesinde|esas alınan varsayım|fiyat tespit raporu|değerlendirme raporu|fonun kullanımına/i;
const DIV_RE = /kar payı|temettü/i;

export function isIpoDisclosure(d: KapDisclosure): boolean {
  const subject = d.subject ?? "";
  const summary = d.summary ?? "";
  if (IPO_EXCLUDE_RE.test(subject) || IPO_EXCLUDE_RE.test(summary)) return false;
  return IPO_RE.test(subject) || IPO_RE.test(summary);
}

export function isDividendDisclosure(d: KapDisclosure): boolean {
  return DIV_RE.test(d.subject ?? "") || DIV_RE.test(d.summary ?? "");
}

export function kapDetailUrl(idx: number): string {
  return DETAIL_URL(idx);
}
