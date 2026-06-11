import SwiftUI
import SwiftData

struct DividendListView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Query private var followed: [FollowedStock]
    @State private var seg: Seg = .upcoming

    enum Seg: Hashable { case upcoming, watch, past }

    private var followedTickers: Set<String> { Set(followed.map(\.ticker)) }

    private var rows: [Dividend] {
        switch seg {
        case .upcoming: return DividendCalendar.upcoming(feed.feed.dividends)
        case .past: return DividendCalendar.past(feed.feed.dividends)
        case .watch: return DividendCalendar.upcoming(feed.feed.dividends).filter { followedTickers.contains($0.ticker) }
        }
    }

    private var next: Dividend? { DividendCalendar.upcoming(feed.feed.dividends).first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Temettü Takvimi")
                    .manrope(30, .heavy)
                    .padding(.horizontal, 6).padding(.top, 6)

                if let next { hero(next) }

                UnderlineTabs(selection: $seg, options: [
                    (.upcoming, "Yaklaşan"), (.watch, "Takip"), (.past, "Geçmiş"),
                ])
                .padding(.horizontal, 6)

                if rows.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Divider().background(Brand.line) }
                            NavigationLink(value: d.ticker) { row(d) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, 120)
        }
        .background(Brand.screen)
        .refreshable { await feed.refresh() }
    }

    private func hero(_ d: Dividend) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sıradaki · \(d.ticker)")
                .manrope(14, .semibold).foregroundStyle(Brand.ink3)
            MoneyText(value: d.netPerShare ?? 0, fraction: 4, size: 42)
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("\(d.ticker) · Verim").manrope(13.5, .semibold).foregroundStyle(Brand.ink2)
                    YieldText(pct: d.yieldPct, size: 13.5)
                }
                Text("·").foregroundStyle(Brand.ink3)
                Text(TRFormat.relativeDays(to: d.exDateValue)).manrope(13.5, .bold).foregroundStyle(Brand.accent2)
                Text("·").foregroundStyle(Brand.ink3)
                Text(TRFormat.date(d.exDateValue)).manrope(13.5, .semibold).foregroundStyle(Brand.ink2)
            }
            .lineLimit(1).minimumScaleFactor(0.8)

            HStack(spacing: 10) {
                let on = followedTickers.contains(d.ticker)
                PillButton(title: on ? "Takipte" : "Takibe al",
                           icon: on ? "star.fill" : "star",
                           variant: on ? .soft : .solid) { toggleFollow(d.ticker) }
                NavigationLink(value: d.ticker) {
                    HStack(spacing: 7) {
                        Text("Detay").manrope(14.5, .bold)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Brand.ink2)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Brand.line, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 6)
    }

    private func row(_ d: Dividend) -> some View {
        HStack(spacing: 13) {
            GradientAvatar(ticker: d.ticker, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(d.ticker).manrope(16.5, .heavy)
                HStack(spacing: 4) {
                    Text(TRFormat.relativeDays(to: d.exDateValue)).manrope(13, .bold).foregroundStyle(Brand.accent2)
                    Text("· \(TRFormat.date(d.exDateValue))").manrope(13, .semibold).foregroundStyle(Brand.ink3)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                MoneyText(value: d.netPerShare ?? 0, fraction: 4, size: 16.5)
                YieldText(pct: d.yieldPct, size: 13.5)
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 6)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock").font(.largeTitle).foregroundStyle(Brand.ink3)
            Text(seg == .watch ? "Takip ettiğin temettü yok" : "Kayıt yok")
                .manrope(16, .bold)
            Text(seg == .watch ? "Takip sekmesinden hisse ekle." : "Veri güncelleniyor.")
                .manrope(13, .medium).foregroundStyle(Brand.ink3)
        }
        .frame(maxWidth: .infinity).padding(.top, 50)
    }

    private func toggleFollow(_ ticker: String) {
        if let existing = followed.first(where: { $0.ticker == ticker }) {
            context.delete(existing)
        } else {
            context.insert(FollowedStock(ticker: ticker))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { _ = await NotificationService.requestAuthorization() }
        }
    }
}
