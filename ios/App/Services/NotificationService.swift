import Foundation
import UserNotifications

// Local notifications only — no push server, no device tokens, no backend.
// On each feed refresh we (re)schedule reminders for followed stocks' upcoming
// ex-dates and for new IPOs. This keeps the whole app server-free.

enum NotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Rebuild the full schedule from the current feed + user's follow list.
    static func reschedule(
        feed: Feed,
        followedTickers: Set<String>,
        notifyAllIPOs: Bool,
        daysBefore: Int
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let today = cal.startOfDay(for: .now)

        // Dividend ex-date reminders for followed stocks.
        for dividend in feed.dividends {
            guard followedTickers.contains(dividend.ticker), let ex = dividend.exDateValue else { continue }
            guard let fireDay = cal.date(byAdding: .day, value: -daysBefore, to: ex), fireDay >= today else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = 9
            let when = TRFormat.relativeDays(to: ex).lowercased()
            schedule(
                center,
                id: "div-\(dividend.id)",
                title: "\(dividend.ticker) temettü",
                body: "Hak kullanım tarihi \(when) (\(TRFormat.date(ex))). Net \(TRFormat.perShare(dividend.netPerShare)).",
                comps: comps
            )
        }

        // New / upcoming IPO reminders.
        if notifyAllIPOs {
            for ipo in feed.ipos {
                guard let start = FeedDate.parse(ipo.subscriptionStart) else { continue }
                guard let fireDay = cal.date(byAdding: .day, value: -daysBefore, to: start), fireDay >= today else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
                comps.hour = 10
                schedule(
                    center,
                    id: "ipo-\(ipo.id)",
                    title: "Halka arz: \(ipo.company)",
                    body: "Talep toplama \(TRFormat.relativeDays(to: start).lowercased()) başlıyor.",
                    comps: comps
                )
            }
        }
    }

    private static func schedule(
        _ center: UNUserNotificationCenter,
        id: String,
        title: String,
        body: String,
        comps: DateComponents
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
