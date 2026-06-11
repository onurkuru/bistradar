import Foundation
import SwiftData

// Local-only watchlist + reminder prefs. No account, no backend — matches the
// app's privacy-first, zero-cost model.

@Model
final class FollowedStock {
    var ticker: String = ""
    var addedAt: Date = Date.now
    var notifyDividend: Bool = true
    var notifyIPO: Bool = false

    init(ticker: String, notifyDividend: Bool = true, notifyIPO: Bool = false) {
        self.ticker = ticker
        self.notifyDividend = notifyDividend
        self.notifyIPO = notifyIPO
    }
}

@Model
final class AppPrefs {
    var remindDaysBefore: Int = 1
    var notifyAllIPOs: Bool = true
    var lastSyncISO: String = ""

    init() {}
}
