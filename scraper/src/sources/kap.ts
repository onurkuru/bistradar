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

/** Fetch every listed-company disclosure between two ISO dates (inclusive). */
export async function fetchDisclosures(fromISO: string, toISO: string): Promise<KapDisclosure[]> {
  const browser = await chromium.launch({ headless: true });
  try {
    return await queryWindow(browser, fromISO, toISO);
  } finally {
    await browser.close();
  }
}

async function queryWindow(browser: Browser, fromISO: string, toISO: string): Promise<KapDisclosure[]> {
  const ctx = await browser.newContext({ userAgent: UA, locale: "tr-TR" });
  const page = await ctx.newPage();
  await page.goto("https://www.kap.org.tr/tr/bildirim-sorgu", { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForTimeout(1500);

  const payload = JSON.stringify({
    fromDate: fromISO, toDate: toISO, memberType: "IGS",
    mkkMemberOidList: [], inactiveMkkMemberOidList: [], disclosureClass: "",
    subjectList: [], isLate: "", mainSector: "", sector: "", subSector: "",
    marketOid: "", index: "", bdkReview: "", bdkMemberOidList: [], year: "",
    term: "", ruleType: "", period: "", fromSrc: false, srcCategory: "",
    disclosureIndexList: [],
  });

  const data: KapDisclosure[] = await page.evaluate(async (body) => {
    const r = await fetch("/tr/api/disclosure/members/byCriteria", {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json" },
      body,
    });
    if (!r.ok) throw new Error("byCriteria -> " + r.status);
    return r.json();
  }, payload);

  return data;
}

// --- classification helpers ---

const IPO_RE = /halka arz|izahna|pay.*halka|borsada işlem görme|ilk işlem günü/i;
const DIV_RE = /kar payı|temettü/i;

export function isIpoDisclosure(d: KapDisclosure): boolean {
  return IPO_RE.test(d.subject ?? "") || IPO_RE.test(d.summary ?? "");
}

export function isDividendDisclosure(d: KapDisclosure): boolean {
  return DIV_RE.test(d.subject ?? "") || DIV_RE.test(d.summary ?? "");
}

export function kapDetailUrl(idx: number): string {
  return DETAIL_URL(idx);
}
