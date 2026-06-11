import SwiftUI
import SwiftData
import Charts

struct StockDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(FeedService.self) private var feed
    @Query private var followed: [FollowedStock]
    let ticker: String

    @State private var range: PriceRange = .threeMonths

    private var stock: StockInfo? { feed.feed.stocks?[ticker] }
    private var down: Bool { (stock?.changePct ?? 0) < 0 }
    private var chartColor: Color { down ? Color(hex: 0xFF5A52) : Color(hex: 0x22D58A) }

    private var history: [Dividend] {
        feed.feed.dividends.filter { $0.ticker == ticker }
            .sorted { ($0.exDateValue ?? .distantPast) > ($1.exDateValue ?? .distantPast) }
    }
    private var upcoming: Dividend? { DividendCalendar.upcoming(history).first }
    private var pastDividends: [Dividend] { DividendCalendar.past(history) }
    private var isFollowed: Bool { followed.contains { $0.ticker == ticker } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                header
                if filteredPrices.count > 1 { chartBlock }
                actionPills
                if let next = upcoming { upcomingCard(next).padding(.top, 14) }
                if !pastDividends.isEmpty { historyCard.padding(.top, 14) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Brand.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: Nav

    private var navBar: some View {
        HStack {
            iconButton("chevron.left") { dismiss() }
            Spacer()
            iconButton(isFollowed ? "bookmark.fill" : "bookmark") { toggleFollow() }
        }
    }

    private func iconButton(_ name: String, size: CGFloat = 40, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                GradientAvatar(ticker: ticker, size: 30)
                Text(ticker).manrope(19, .heavy).foregroundStyle(.white)
                Text("Borsa İstanbul").manrope(14, .semibold).foregroundStyle(.white.opacity(0.45))
            }
            .padding(.top, 16)

            if let last = stock?.lastClose {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    MoneyText(value: last, fraction: 2, size: 42, color: .white)
                    YieldText(pct: stock?.changePct, size: 20)
                }
                .padding(.top, 6)
            } else {
                Text("Fiyat verisi yok").manrope(15, .semibold).foregroundStyle(.white.opacity(0.5)).padding(.top, 6)
            }
        }
    }

    // MARK: Chart

    private var chartBlock: some View {
        VStack(spacing: 12) {
            chart
                .frame(height: 220)
                .padding(.horizontal, -18)   // edge-to-edge
                .padding(.top, 16)
            HStack(spacing: 5) {
                ForEach(PriceRange.allCases) { r in
                    Button { withAnimation(.easeInOut(duration: 0.2)) { range = r } } label: {
                        Text(r.label).manrope(13, .bold)
                            .foregroundStyle(range == r ? .white : .white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(range == r ? Color.white.opacity(0.14) : .clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var chart: some View {
        let pts = filteredPrices
        let base = pts.first?.c ?? 0
        let lo = pts.map(\.c).min() ?? 0
        let hi = pts.map(\.c).max() ?? 1
        let pad = max((hi - lo) * 0.08, 0.01)
        return Chart {
            RuleMark(y: .value("base", base))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                .foregroundStyle(.white.opacity(0.16))
            ForEach(pts, id: \.d) { p in
                if let date = p.date {
                    AreaMark(x: .value("t", date), y: .value("c", p.c))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [chartColor.opacity(0.26), chartColor.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("t", date), y: .value("c", p.c))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(chartColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
            }
            if let lastP = pts.last, let date = lastP.date {
                PointMark(x: .value("t", date), y: .value("c", lastP.c))
                    .symbolSize(180).foregroundStyle(chartColor.opacity(0.22))
                PointMark(x: .value("t", date), y: .value("c", lastP.c))
                    .symbolSize(55).foregroundStyle(chartColor)
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis(.hidden).chartYAxis(.hidden)
    }

    private var filteredPrices: [PricePoint] {
        let all = stock?.prices ?? []
        guard let days = range.days else { return all }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let f = all.filter { ($0.date ?? .distantPast) >= cutoff }
        return f.count > 1 ? f : all
    }

    // MARK: Actions

    private var actionPills: some View {
        HStack(spacing: 10) {
            PillButton(title: isFollowed ? "Takipte" : "Takibe al",
                       icon: isFollowed ? "star.fill" : "star",
                       variant: .solid) { toggleFollow() }
            Spacer()
        }
        .padding(.top, 20)
    }

    // MARK: Dividend cards (dark)

    private func upcomingCard(_ next: Dividend) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Yaklaşan temettü").manrope(16, .heavy).foregroundStyle(.white)
                Spacer()
                Text(TRFormat.relativeDays(to: next.exDateValue))
                    .manrope(12.5, .bold).foregroundStyle(Color(hex: 0xFF6A60))
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color(hex: 0xFF5A52).opacity(0.16), in: Capsule())
            }
            HStack(spacing: 10) {
                darkStat("Hak kullanım") { AnyView(Text(TRFormat.date(next.exDateValue)).manrope(15.5, .heavy).foregroundStyle(.white)) }
                darkStat("Net / pay") { AnyView(MoneyText(value: next.netPerShare ?? 0, fraction: 4, size: 15.5, color: .white)) }
                darkStat("Verim", alignTrailing: true) { AnyView(YieldText(pct: next.yieldPct, size: 17)) }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.darkCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func darkStat(_ label: String, alignTrailing: Bool = false, @ViewBuilder value: () -> AnyView) -> some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 6) {
            Text(label).manrope(12.5, .semibold).foregroundStyle(.white.opacity(0.45))
            value()
        }
        .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Geçmiş temettüler").manrope(16, .heavy).foregroundStyle(.white).padding(.bottom, 8)
            ForEach(Array(pastDividends.enumerated()), id: \.element.id) { i, d in
                if i > 0 { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
                HStack {
                    Text(TRFormat.date(d.exDateValue)).manrope(14.5, .semibold).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    MoneyText(value: d.netPerShare ?? 0, fraction: 4, size: 15, color: .white)
                        .padding(.trailing, 16)
                    YieldText(pct: d.yieldPct, size: 14.5)
                }
                .padding(.vertical, 13)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.darkCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func toggleFollow() {
        if let existing = followed.first(where: { $0.ticker == ticker }) {
            context.delete(existing)
        } else {
            context.insert(FollowedStock(ticker: ticker))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { _ = await NotificationService.requestAuthorization() }
        }
    }
}

enum PriceRange: String, CaseIterable, Identifiable {
    case week, oneMonth, threeMonths, sixMonths, year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week: return "1G"
        case .oneMonth: return "1A"
        case .threeMonths: return "3A"
        case .sixMonths: return "6A"
        case .year: return "1Y"
        }
    }
    var days: Int? {
        switch self {
        case .week: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return nil
        }
    }
}
