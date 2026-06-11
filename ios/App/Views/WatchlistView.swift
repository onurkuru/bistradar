import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Environment(PremiumStore.self) private var premium
    @Query(sort: \FollowedStock.addedAt) private var followed: [FollowedStock]
    @State private var adding = false
    @State private var newTicker = ""
    @State private var showPaywall = false

    static let freeLimit = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Takip").manrope(30, .heavy)
                    Spacer()
                    Button { tryAdd() } label: {
                        Image(systemName: "plus").font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Brand.accent)
                            .frame(width: 42, height: 42)
                            .background(Brand.section, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6).padding(.top, 6)

                if followed.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(followed.enumerated()), id: \.element.id) { i, stock in
                            if i > 0 { Divider().background(Brand.line) }
                            NavigationLink(value: stock.ticker) {
                                row(stock)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !premium.isPremium {
                        Button { showPaywall = true } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "crown.fill")
                                Text("Premium ile sınırsız takip").manrope(15, .bold)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(Brand.accent)
                            .padding(.horizontal, 16).padding(.vertical, 15)
                            .background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        Text("Ücretsiz sürümde \(Self.freeLimit) hisse takip edebilirsin (\(followed.count)/\(Self.freeLimit)).")
                            .manrope(13, .medium).foregroundStyle(Brand.ink3)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 2)
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, 120)
        }
        .background(Brand.screen)
        .alert("Hisse ekle", isPresented: $adding) {
            TextField("Sembol (örn. GARAN)", text: $newTicker).textInputAutocapitalization(.characters)
            Button("Ekle", action: add)
            Button("Vazgeç", role: .cancel) { newTicker = "" }
        } message: {
            Text("BIST sembolünü gir. Bildirimler bu hisse için açılır.")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func row(_ stock: FollowedStock) -> some View {
        let info = feed.feed.stocks?[stock.ticker]
        let next = nextDividend(for: stock.ticker)
        return HStack(spacing: 13) {
            GradientAvatar(ticker: stock.ticker, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.ticker).manrope(16.5, .heavy)
                if let next {
                    Text("Temettü \(TRFormat.relativeDays(to: next.exDateValue).lowercased()) • \(TRFormat.date(next.exDateValue))")
                        .manrope(13, .semibold).foregroundStyle(Brand.accent2).lineLimit(1)
                } else {
                    Text("Yaklaşan temettü yok").manrope(13, .semibold).foregroundStyle(Brand.ink3)
                }
            }
            Spacer(minLength: 8)
            if let last = info?.lastClose {
                VStack(alignment: .trailing, spacing: 3) {
                    MoneyText(value: last, fraction: 2, size: 16.5)
                    YieldText(pct: info?.changePct, size: 13.5)
                }
            } else {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).foregroundStyle(Brand.ink3)
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 6)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star").font(.largeTitle).foregroundStyle(Brand.ink3)
            Text("Takip listen boş").manrope(16, .bold)
            Text("Takip ettiğin hisselerin temettü tarihleri yaklaşınca bildirim alırsın.")
                .manrope(13, .medium).foregroundStyle(Brand.ink3).multilineTextAlignment(.center)
            PillButton(title: "Hisse Ekle", icon: "plus", variant: .solid) { tryAdd() }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    private func tryAdd() {
        if !premium.isPremium && followed.count >= Self.freeLimit { showPaywall = true }
        else { adding = true }
    }

    private func nextDividend(for ticker: String) -> Dividend? {
        DividendCalendar.upcoming(feed.feed.dividends).first { $0.ticker == ticker }
    }

    private func add() {
        let symbol = newTicker.trimmingCharacters(in: .whitespaces).uppercased()
        newTicker = ""
        guard !symbol.isEmpty, !followed.contains(where: { $0.ticker == symbol }) else { return }
        context.insert(FollowedStock(ticker: symbol))
    }
}
