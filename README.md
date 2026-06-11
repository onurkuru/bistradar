# Arz Radar

Turkish-market iOS app: **temettü (dividend) calendar + halka arz (IPO) tracker**
with local push reminders. Data comes only from **official / broker-grade**
sources — KAP (the legally-mandated disclosure platform) and İş Yatırım (a
licensed brokerage). No hobby-site scraping, no account, no backend server.

## Architecture (zero running cost)

```
KAP (official) ──┐
İş Yatırım ───────┤→ scraper/ (Node + Playwright)
SPK bulletin ─────┘        │  GitHub Actions cron, 4×/day, FREE
                           ▼
                    data/feed.json  ──(jsDelivr CDN)──►  ios/  (SwiftUI app)
                                                          local notifications
```

- **`scraper/`** — see [scraper/README.md](scraper/README.md). Produces `data/feed.json`.
- **`data/feed.json`** — the IPO + dividend calendar, committed by the Action.
- **`ios/`** — SwiftUI + SwiftData app (iOS 17+). Reads feed.json from the CDN with
  a bundled fallback; schedules **local** notifications for followed stocks'
  ex-dates and new IPOs (no push server, no device tokens).

## Why this is reliable

Turkey has no free, documented, institutional JSON API for this data. Every bank/
broker app either scrapes KAP or pays a vendor (Foreks/Matriks/Finnet). We use
KAP directly — the legal source of truth — driven through a headless browser to
get past its TLS-fingerprint WAF, and enrich dividend detail from İş Yatırım.
Verified end-to-end 2026-06: forward-looking dividend calendar with real ex-dates,
gross/net per share, and yield.

## iOS build

```bash
cd ios
xcodegen generate
open BistRadar.xcodeproj   # scheme: BistRadar
# tests: xcodebuild -project BistRadar.xcodeproj -scheme BistRadar \
#   -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

The app reads the feed from GitHub raw
(`https://raw.githubusercontent.com/<user>/bistradar/main/data/feed.json`,
Fastly-cached ~5 min) — fresher than jsDelivr's 12h branch cache and needs no
purge step. Set `FeedService.remoteURL` to your path.

## Compliance

Shows only public disclosure data. Clearly labeled "yatırım tavsiyesi değildir"
(not investment advice) — no buy/sell guidance, so it stays outside SPK
investment-advisory licensing.

## Remaining work

- Real AdMob unit ID + Google Mobile Ads SDK (slot + Premium gate already in place).
- Optional server-push (APNs from the Action) if instant alerts are wanted over the
  current local-notification model.
- ASO + naming pass + App Store Connect setup (Team, app, IAP) before submission.

Done: IPO detail enrichment — `scraper/src/sources/parseIpo.ts` pulls subscription
dates, price (fixed/range), listing date and method from each KAP disclosure detail
page (verified live; broker-noise filtered, stale entries expire after 45 days).
