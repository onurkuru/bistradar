import Foundation

// Mirrors the scraper's data/feed.json contract exactly. Decoded straight off
// the CDN — keep field names in sync with scraper/src/types.ts.

struct Feed: Codable, Equatable {
    var generatedAt: String
    var ipos: [IPO]
    var dividends: [Dividend]

    static let empty = Feed(generatedAt: "", ipos: [], dividends: [])
}

struct IPO: Codable, Equatable, Identifiable, Hashable {
    var ticker: String
    var company: String
    var status: String
    var subscriptionStart: String?
    var subscriptionEnd: String?
    var listingDate: String?
    var priceMin: Double?
    var priceMax: Double?
    var priceFixed: Double?
    var lotCount: Double?
    var method: String?
    var market: String?
    var intermediary: String?
    var sourceUrl: String
    var disclosureId: String?
    var updatedAt: String

    var id: String { disclosureId ?? "\(ticker)-\(company)" }

    var statusKind: IPOStatus {
        IPOStatus(rawValue: status) ?? .upcoming
    }

    /// Best available date to sort/display by.
    var keyDate: Date? {
        FeedDate.parse(subscriptionStart) ?? FeedDate.parse(listingDate) ?? FeedDate.parse(updatedAt)
    }
}

enum IPOStatus: String {
    case upcoming, collecting, listed, draft

    var label: String {
        switch self {
        case .upcoming: return "Yaklaşan"
        case .collecting: return "Talep Toplama"
        case .listed: return "İşlemde"
        case .draft: return "Taslak"
        }
    }
}

struct Dividend: Codable, Equatable, Identifiable, Hashable {
    var ticker: String
    var company: String?
    var exDate: String
    var paymentDate: String?
    var grossPerShare: Double?
    var netPerShare: Double?
    var yieldPct: Double?
    var payoutRatioPct: Double?
    var totalAmount: Double?
    var source: String
    var sourceUrl: String
    var announced: Bool
    var updatedAt: String

    var id: String { "\(ticker)|\(exDate)" }

    var exDateValue: Date? { FeedDate.parse(exDate) }

    var isUpcoming: Bool {
        guard let d = exDateValue else { return false }
        return d >= Calendar.current.startOfDay(for: .now)
    }
}

enum FeedDate {
    /// Feed dates are ISO "yyyy-MM-dd" (or full ISO8601 for timestamps).
    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let d = dayFormatter.date(from: String(string.prefix(10))) { return d }
        return ISO8601DateFormatter().date(from: string)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
