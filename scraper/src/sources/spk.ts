// SPK (spk.gov.tr) weekly bulletin — official regulator source for IPO prospectus
// (izahname) approvals. Used as a secondary confirmation signal for the IPO
// pipeline. The bulletin list is JS-rendered, so we drive it with Playwright.
//
// NOTE: kept minimal for v1; KAP halka-arz disclosures are the primary IPO source.
import { chromium } from "playwright";

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

export interface SpkBulletinItem {
  title: string;
  url: string;
}

/** Returns recent weekly-bulletin entries (title + link). */
export async function fetchRecentBulletins(): Promise<SpkBulletinItem[]> {
  const browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext({ userAgent: UA, locale: "tr-TR" });
    const page = await ctx.newPage();
    await page.goto("https://www.spk.gov.tr/bulten", { waitUntil: "networkidle", timeout: 60000 }).catch(() => {});
    await page.waitForTimeout(2000);
    const items = await page.$$eval("a", (els) =>
      els
        .map((a) => ({ title: (a.textContent ?? "").trim(), url: (a as HTMLAnchorElement).href }))
        .filter((x) => /bülten|bulten|\.pdf/i.test(x.url) && x.title.length > 3)
        .slice(0, 20),
    );
    return items;
  } finally {
    await browser.close();
  }
}
