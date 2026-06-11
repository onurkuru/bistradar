import SwiftUI
import SwiftData

struct DividendListView: View {
    @Environment(FeedService.self) private var feed
    @Query private var followed: [FollowedStock]
    @State private var scope: Scope = .upcoming
    @State private var query = ""

    enum Scope: String, CaseIterable, Identifiable {
        case upcoming = "Yaklaşan"
        case mine = "Takip"
        case past = "Geçmiş"
        var id: String { rawValue }
    }

    private var followedTickers: Set<String> { Set(followed.map(\.ticker)) }

    private var items: [Dividend] {
        let base: [Dividend]
        switch scope {
        case .upcoming: base = DividendCalendar.upcoming(feed.feed.dividends)
        case .past: base = DividendCalendar.past(feed.feed.dividends)
        case .mine: base = DividendCalendar.upcoming(feed.feed.dividends).filter { followedTickers.contains($0.ticker) }
        }
        guard !query.isEmpty else { return base }
        return base.filter { $0.ticker.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if scope == .upcoming, query.isEmpty {
                    summaryHeader
                }

                Picker("Kapsam", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .screenPadding()

                if items.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, dividend in
                            NavigationLink(value: dividend.ticker) {
                                DividendCard(dividend: dividend)
                            }
                            .buttonStyle(.plain)
                            .screenPadding()

                            if index == 2 { AdBanner() }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Brand.bg)
        .navigationTitle("Temettü Takvimi")
        .navigationDestination(for: String.self) { StockDetailView(ticker: $0) }
        .searchable(text: $query, prompt: "Hisse ara (örn. GARAN)")
        .refreshable { await feed.refresh() }
    }

    private var summaryHeader: some View {
        let upcoming = DividendCalendar.upcoming(feed.feed.dividends)
        let next = upcoming.first
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("\(upcoming.count) yaklaşan temettü", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                if let next {
                    HStack(spacing: 12) {
                        TickerAvatar(ticker: next.ticker, size: 50)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sıradaki: \(next.ticker)")
                                .font(.headline)
                            Text("\(TRFormat.relativeDays(to: next.exDateValue)) • \(TRFormat.date(next.exDateValue))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(TRFormat.perShare(next.netPerShare))
                                .font(.headline)
                                .monospacedDigit()
                            if next.yieldPct != nil {
                                Text("Verim \(TRFormat.percent(next.yieldPct))")
                                    .font(.caption)
                                    .foregroundStyle(Brand.positive)
                            }
                        }
                    }
                }
            }
        }
        .screenPadding()
    }

    private var emptyState: some View {
        ContentUnavailableView(
            scope == .mine ? "Takip ettiğin temettü yok" : "Kayıt yok",
            systemImage: "calendar.badge.clock",
            description: Text(scope == .mine
                ? "Takip sekmesinden hisse ekleyince yaklaşan temettüleri burada görürsün."
                : "Veri güncelleniyor. Aşağı çekerek yenile.")
        )
        .padding(.top, 40)
    }
}

struct DividendCard: View {
    let dividend: Dividend

    var body: some View {
        Card(padding: 14) {
            HStack(spacing: 13) {
                VStack(spacing: 0) {
                    Text(dividend.exDateValue?.formatted(.dateTime.day()) ?? "—")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text(dividend.exDateValue?.formatted(.dateTime.month(.abbreviated)) ?? "")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 42)

                Rectangle().fill(.quaternary).frame(width: 1, height: 36)

                TickerAvatar(ticker: dividend.ticker)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dividend.ticker)
                        .font(.headline)
                    Pill(text: TRFormat.relativeDays(to: dividend.exDateValue), color: badgeColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(TRFormat.perShare(dividend.netPerShare))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                    if dividend.yieldPct != nil {
                        Text("Verim \(TRFormat.percent(dividend.yieldPct))")
                            .font(.caption)
                            .foregroundStyle(Brand.positive)
                    }
                }
            }
        }
    }

    private var badgeColor: Color {
        switch TRFormat.relativeDays(to: dividend.exDateValue) {
        case "Bugün", "Yarın": return Brand.accent
        case "Geçti": return .secondary
        default: return .blue
        }
    }
}
