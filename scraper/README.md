# BIST Radar — data scraper

Builds `../data/feed.json` (the IPO + dividend calendar the iOS app reads) from
**official / broker-grade** sources only. No hobby sites.

## Sources (all verified live, 2026-06)

| Data | Source | How |
|---|---|---|
| Dividend trigger | **KAP** (kap.org.tr, official/legal) | `POST /tr/api/disclosure/members/byCriteria` via headless Chromium (the API rejects plain HTTP via a TLS-fingerprint WAF, but works from a real browser context). Filter "Kar Payı Dağıtım İşlemlerine İlişkin Bildirim". |
| Dividend detail (ex-date, gross/net, yield) | **İş Yatırım** (a licensed brokerage) | `sirket-karti.aspx` HTML `temettugercekvarrow` table, parsed per ticker. Auth-free. |
| IPO (halka arz) | **KAP** | Same byCriteria query, filtered for "Halka Arz / İzahname" subjects. |
| IPO confirmation | **SPK** weekly bulletin (regulator) | `spk.gov.tr/bulten`, secondary signal. |
| Prices (enrichment) | **İş Yatırım** | `Data.aspx/HisseTekil` JSON, auth-free. |

Why this shape: every bank/broker app shows this data by scraping KAP or paying a
vendor (Foreks/Matriks/Finnet). KAP is the legally-mandated disclosure platform,
so it is the most authoritative free source. The 2000-record response cap means
we query a short rolling window each run and accumulate into feed.json.

## Run

```bash
npm install
npx playwright install chromium
npx tsx src/index.ts 4     # sync last 4 days, merge into ../data/feed.json
```

`src/dev-probe-kap.ts` is a development probe for inspecting KAP's API (not part of sync).

## Hosting (zero cost)

`.github/workflows/sync.yml` runs this 4×/day on GitHub Actions (free), commits
`data/feed.json` back to the repo. The iOS app reads it from GitHub raw
(`https://raw.githubusercontent.com/<user>/bistradar/main/data/feed.json`,
Fastly-cached ~5 min).

## Remaining work

- IPO detail enrichment: parse KAP disclosure detail pages for subscription dates
  (talep toplama) and price range — currently IPO records carry company + KAP link only.
- Dividend ex-date from KAP detail when İş Yatırım hasn't recorded a finalized date yet.
