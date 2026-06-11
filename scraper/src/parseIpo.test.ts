// Quick assertion harness for the IPO detail parser (run: npx tsx src/dev-test-parser.ts).
import { parseIpoDetail, deriveStatus } from "./sources/parseIpo.js";

let failures = 0;
function check(name: string, cond: boolean, got?: unknown) {
  if (cond) console.log(`  ok   ${name}`);
  else { console.log(`  FAIL ${name}  got=${JSON.stringify(got)}`); failures++; }
}

// 1) Real KAP narrative (Margün/ESEN accelerated bookbuild).
const margun =
  "Margün Enerji payları ile ilgili olarak 1 TL nominal değerli paylar için satış fiyatı 53,55 TL " +
  "olmak üzere toplam 85.800.000 TL nominal değerli 85.800.000 TL payın hızlandırılmış talep toplama " +
  "yöntemiyle gerçekleştirilen satış işleminin takası 08.06.2026 tarihinde tamamlanmıştır.";
const a = parseIpoDetail(margun);
console.log("Margün:", JSON.stringify(a));
check("margun price 53.55", a.priceFixed === 53.55, a.priceFixed);
check("margun method bookbuild", a.method === "Hızlandırılmış Talep Toplama", a.method);

// 2) Synthetic price-range IPO with subscription window + listing date.
const ranged =
  "Şirket paylarının halka arzında fiyat aralığı 18,00 TL - 22,50 TL olarak belirlenmiştir. " +
  "Talep toplama tarihleri 12.06.2026 ve 13.06.2026 olarak planlanmıştır. Paylar 18.06.2026 " +
  "tarihinde Borsa İstanbul'da işlem görmeye başlayacaktır.";
const b = parseIpoDetail(ranged);
console.log("Ranged:", JSON.stringify(b));
check("range min 18", b.priceMin === 18, b.priceMin);
check("range max 22.5", b.priceMax === 22.5, b.priceMax);
check("sub start", b.subscriptionStart === "2026-06-12", b.subscriptionStart);
check("sub end", b.subscriptionEnd === "2026-06-13", b.subscriptionEnd);
check("listing", b.listingDate === "2026-06-18", b.listingDate);
check("status upcoming", deriveStatus(b, "2026-06-10") === "upcoming", deriveStatus(b, "2026-06-10"));
check("status collecting", deriveStatus(b, "2026-06-12") === "collecting", deriveStatus(b, "2026-06-12"));
check("status listed", deriveStatus(b, "2026-06-20") === "listed", deriveStatus(b, "2026-06-20"));

// 3) Fixed-price IPO.
const fixed =
  "Halka arz fiyatı 9,40 TL olarak belirlenmiştir. Sabit fiyatla talep toplama 05.05.2026 - 06.05.2026 " +
  "tarihleri arasında gerçekleştirilecektir.";
const c = parseIpoDetail(fixed);
console.log("Fixed:", JSON.stringify(c));
check("fixed price 9.40", c.priceFixed === 9.4, c.priceFixed);
check("fixed method", c.method === "Sabit Fiyat", c.method);

console.log(failures === 0 ? "\nALL PASSED" : `\n${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
