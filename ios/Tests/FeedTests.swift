import XCTest

final class FeedTests: XCTestCase {

    private let sampleJSON = """
    {
      "generatedAt": "2026-06-11T06:51:13.482Z",
      "dividends": [
        {"ticker":"LOGO","exDate":"2026-06-15","grossPerShare":5.2632,"netPerShare":4.4737,"yieldPct":3.71,"payoutRatioPct":30,"totalAmount":500000000,"source":"isyatirim","sourceUrl":"https://x","announced":true,"updatedAt":"2026-06-11T06:51:20.635Z"},
        {"ticker":"ULKER","exDate":"2020-06-19","grossPerShare":1.0,"netPerShare":0.85,"yieldPct":5.01,"source":"isyatirim","sourceUrl":"https://x","announced":false,"updatedAt":"2026-06-11T06:51:32.791Z"}
      ],
      "ipos": []
    }
    """

    func testDecodesFeed() throws {
        let feed = try JSONDecoder().decode(Feed.self, from: Data(sampleJSON.utf8))
        XCTAssertEqual(feed.dividends.count, 2)
        XCTAssertEqual(feed.dividends[0].ticker, "LOGO")
        XCTAssertEqual(feed.dividends[0].netPerShare ?? 0, 4.4737, accuracy: 0.0001)
    }

    func testExDateParsing() {
        let d = Dividend(ticker: "LOGO", company: nil, exDate: "2026-06-15", paymentDate: nil,
                         grossPerShare: nil, netPerShare: nil, yieldPct: nil, payoutRatioPct: nil,
                         totalAmount: nil, source: "isyatirim", sourceUrl: "", announced: true, updatedAt: "")
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: d.exDateValue!)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 15)
    }

    func testUpcomingFiltersAndSorts() {
        let now = FeedDate.parse("2026-06-11")!
        let divs = [
            mkDiv("A", "2026-06-20"),
            mkDiv("B", "2026-06-12"),
            mkDiv("C", "2020-01-01"), // past
        ]
        let upcoming = DividendCalendar.upcoming(divs, now: now)
        XCTAssertEqual(upcoming.map(\.ticker), ["B", "A"])
        let past = DividendCalendar.past(divs, now: now)
        XCTAssertEqual(past.map(\.ticker), ["C"])
    }

    func testRelativeDays() {
        let now = FeedDate.parse("2026-06-11")!
        XCTAssertEqual(TRFormat.relativeDays(to: FeedDate.parse("2026-06-11"), now: now), "Bugün")
        XCTAssertEqual(TRFormat.relativeDays(to: FeedDate.parse("2026-06-12"), now: now), "Yarın")
        XCTAssertEqual(TRFormat.relativeDays(to: FeedDate.parse("2026-06-15"), now: now), "4 gün sonra")
        XCTAssertEqual(TRFormat.relativeDays(to: FeedDate.parse("2026-06-01"), now: now), "Geçti")
    }

    func testPerShareFormatting() {
        XCTAssertEqual(TRFormat.perShare(nil), "—")
        XCTAssertTrue(TRFormat.perShare(4.4737).contains("4,47"))
    }

    private func mkDiv(_ ticker: String, _ exDate: String) -> Dividend {
        Dividend(ticker: ticker, company: nil, exDate: exDate, paymentDate: nil,
                 grossPerShare: nil, netPerShare: 1.0, yieldPct: 3.0, payoutRatioPct: nil,
                 totalAmount: nil, source: "isyatirim", sourceUrl: "", announced: true, updatedAt: "")
    }
}
