import SwiftUI
import SwiftData
import Charts

struct StockDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Query private var followed: [FollowedStock]
    let ticker: String

    @State private var range: PriceRange = .threeMonths

    private var stock: StockInfo? { feed.feed.stocks?[ticker] }

    private var history: [Dividend] {
        feed.feed.dividends
            .filter { $0.ticker == ticker }
            .sorted { ($0.exDateValue ?? .distantPast) > ($1.exDateValue ?? .distantPast) }
    }

    private var upcoming: Dividend? { DividendCalendar.upcoming(history).first }
    private var pastDividends: [Dividend] { DividendCalendar.past(history) }
    private var isFollowed: Bool { followed.contains { $0.ticker == ticker } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                priceHero
                if let next = upcoming { upcomingCard(next) }
                if !pastDividends.isEmpty { historySection }
                attribution
            }
            .padding(.vertical, 12)
        }
        .background(Brand.bg)
        .navigationTitle(ticker)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleFollow) {
                    Image(systemName: isFollowed ? "star.fill" : "star")
                        .foregroundStyle(isFollowed ? .yellow : .secondary)
                }
                .accessibilityLabel(isFollowed ? "Takipten çıkar" : "Takip et")
            }
        }
    }

    // MARK: - Dark price hero (Midas-style)

    private var priceHero: some View {
        let pts = filteredPrices
        let up = (stock?.changePct ?? 0) >= 0
        let lineColor = up ? Brand.positive : Brand.negative
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TickerAvatar(ticker: ticker, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticker).font(.title3.weight(.bold)).foregroundStyle(.white)
                    Text("Borsa İstanbul").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            if let last = stock?.lastClose {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(TRFormat.perShare(last))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let chg = stock?.changePct {
                        Text("\(chg >= 0 ? "+" : "")\(TRFormat.percent(chg))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(lineColor)
                    }
                }
            } else {
                Text("Fiyat verisi yok")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if pts.count > 1 {
                priceChart(pts, color: lineColor)
                    .frame(height: 160)
                rangePicker
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.15), .black],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .screenPadding()
    }

    private func priceChart(_ pts: [PricePoint], color: Color) -> some View {
        let lo = pts.map(\.c).min() ?? 0
        let hi = pts.map(\.c).max() ?? 1
        let pad = (hi - lo) * 0.08
        return Chart(pts, id: \.d) { p in
            if let date = p.date {
                LineMark(x: .value("Tarih", date), y: .value("Fiyat", p.c))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                AreaMark(x: .value("Tarih", date), y: .value("Fiyat", p.c))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), .clear],
                                                    startPoint: .top, endPoint: .bottom))
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(PriceRange.allCases) { r in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { range = r }
                } label: {
                    Text(r.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(range == r ? .white : .white.opacity(0.12))
                        .foregroundStyle(range == r ? .black : .white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var filteredPrices: [PricePoint] {
        let all = stock?.prices ?? []
        guard let days = range.days else { return all }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return all.filter { ($0.date ?? .distantPast) >= cutoff }
    }

    // MARK: - Dividend cards

    private func upcomingCard(_ next: Dividend) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Yaklaşan temettü", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Pill(text: TRFormat.relativeDays(to: next.exDateValue),
                         color: Brand.accent)
                }
                HStack(spacing: 0) {
                    stat("Hak kullanım", TRFormat.date(next.exDateValue))
                    stat("Net / pay", TRFormat.perShare(next.netPerShare))
                    stat("Verim", TRFormat.percent(next.yieldPct), tint: Brand.positive)
                }
            }
        }
        .screenPadding()
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.bold)).foregroundStyle(tint)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historySection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Geçmiş temettüler")
                    .font(.headline)
                ForEach(pastDividends) { d in
                    HStack {
                        Text(TRFormat.date(d.exDateValue))
                            .font(.subheadline)
                        Spacer()
                        Text(TRFormat.perShare(d.netPerShare))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        if d.yieldPct != nil {
                            Text(TRFormat.percent(d.yieldPct))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Brand.positive)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    if d.id != pastDividends.last?.id { Divider() }
                }
            }
        }
        .screenPadding()
    }

    private var attribution: some View {
        Text("Veriler KAP ve İş Yatırım kaynaklıdır. Yatırım tavsiyesi değildir.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .screenPadding()
            .padding(.top, 4)
    }

    private func toggleFollow() {
        if let existing = followed.first(where: { $0.ticker == ticker }) {
            context.delete(existing)
        } else {
            context.insert(FollowedStock(ticker: ticker))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

enum PriceRange: String, CaseIterable, Identifiable {
    case oneMonth, threeMonths, sixMonths
    var id: String { rawValue }
    var label: String {
        switch self {
        case .oneMonth: return "1A"
        case .threeMonths: return "3A"
        case .sixMonths: return "6A"
        }
    }
    var days: Int? {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return nil // all (~180d)
        }
    }
}
