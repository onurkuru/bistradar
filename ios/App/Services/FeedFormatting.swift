import Foundation

// Pure formatting helpers, unit-tested (no UIKit/SwiftUI imports so they compile
// into the test target).

enum TRFormat {
    static let lira: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.numberStyle = .currency
        f.currencyCode = "TRY"
        f.maximumFractionDigits = 2
        return f
    }()

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        return lira.string(from: value as NSNumber) ?? "—"
    }

    static func perShare(_ value: Double?) -> String {
        guard let value else { return "—" }
        // Dividends per share are small; show up to 4 decimals.
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        return (f.string(from: value as NSNumber) ?? "—") + " ₺"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.maximumFractionDigits = 2
        return "%" + (f.string(from: value as NSNumber) ?? "0")
    }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        return dayMonth.string(from: date)
    }

    /// "Yarın", "3 gün sonra", "Bugün", "Geçti" relative to today (Istanbul).
    static func relativeDays(to date: Date?, now: Date = .now) -> String {
        guard let date else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "Geçti"
        case 0: return "Bugün"
        case 1: return "Yarın"
        default: return "\(days) gün sonra"
        }
    }
}

enum DividendCalendar {
    /// Upcoming dividends grouped/sorted by ex-date ascending.
    static func upcoming(_ dividends: [Dividend], now: Date = .now) -> [Dividend] {
        let today = Calendar.current.startOfDay(for: now)
        return dividends
            .filter { ($0.exDateValue ?? .distantPast) >= today }
            .sorted { ($0.exDateValue ?? .distantFuture) < ($1.exDateValue ?? .distantFuture) }
    }

    static func past(_ dividends: [Dividend], now: Date = .now) -> [Dividend] {
        let today = Calendar.current.startOfDay(for: now)
        return dividends
            .filter { ($0.exDateValue ?? .distantPast) < today }
            .sorted { ($0.exDateValue ?? .distantPast) > ($1.exDateValue ?? .distantPast) }
    }
}
