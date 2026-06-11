// Probe 4b: evaluate() only does the raw fetch (no inner helpers — esbuild's
// __name injection breaks those in the page). All filtering happens in Node.
import { chromium } from "playwright";

const browser = await chromium.launch({ headless: true });
const ctx = await browser.newContext({
  userAgent:
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
  locale: "tr-TR",
});
const page = await ctx.newPage();
await page.goto("https://www.kap.org.tr/tr/bildirim-sorgu", { waitUntil: "domcontentloaded", timeout: 60000 }).catch(() => {});
await page.waitForTimeout(1500);

const payload = JSON.stringify({
  fromDate: "2026-03-12", toDate: "2026-06-10", memberType: "IGS",
  mkkMemberOidList: [], inactiveMkkMemberOidList: [], disclosureClass: "",
  subjectList: [], isLate: "", mainSector: "", sector: "", subSector: "",
  marketOid: "", index: "", bdkReview: "", bdkMemberOidList: [], year: "",
  term: "", ruleType: "", period: "", fromSrc: false, srcCategory: "",
  disclosureIndexList: [],
});

const all: any[] = await page.evaluate(async (body) => {
  const r = await fetch("/tr/api/disclosure/members/byCriteria", {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json" },
    body,
  });
  return r.json();
}, payload);

await browser.close();

const ipoRe = /halka arz|izahna|pay.*halka|borsada işlem görme|ilk işlem/i;
const divRe = /kar payı|temettü/i;
const match = (d: any, re: RegExp) => re.test(d.subject ?? "") || re.test(d.summary ?? "");
const pick = (d: any) => `${d.publishDate} | ${d.stockCodes ?? "-"} | ${d.disclosureCategory} | ${d.subject} | ${(d.summary ?? "").slice(0, 70)}`;

const ipos = all.filter((d) => match(d, ipoRe));
const divs = all.filter((d) => match(d, divRe));

console.log(`Total disclosures (90d, IGS): ${all.length}`);
console.log(`\n=== IPO-related (${ipos.length}) ===`);
ipos.slice(0, 10).forEach((d) => console.log(pick(d)));
console.log(`\n=== Dividend-related (${divs.length}) ===`);
divs.slice(0, 10).forEach((d) => console.log(pick(d)));

// Distinct categories among dividend hits — to learn KAP's category code.
console.log("\nDividend disclosureCategory codes:", [...new Set(divs.map((d) => d.disclosureCategory))].join(", "));
console.log("IPO disclosureCategory codes:", [...new Set(ipos.map((d) => d.disclosureCategory))].join(", "));
