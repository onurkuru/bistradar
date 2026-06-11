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
        List {
            if followed.isEmpty {
                ContentUnavailableView {
                    Label("Takip listen boş", systemImage: "star")
                } description: {
                    Text("Takip ettiğin hisselerin temettü hak kullanım tarihleri yaklaşınca bildirim alırsın.")
                } actions: {
                    Button("Hisse Ekle") { tryAdd() }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.accent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(followed) { stock in
                    NavigationLink(value: stock.ticker) {
                        WatchRow(stock: stock,
                                 nextDividend: nextDividend(for: stock.ticker),
                                 info: feed.feed.stocks?[stock.ticker])
                    }
                }
                .onDelete(perform: remove)

                if !premium.isPremium {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Premium ile sınırsız takip", systemImage: "crown.fill")
                                .foregroundStyle(Brand.accent)
                        }
                    } footer: {
                        Text("Ücretsiz sürümde \(Self.freeLimit) hisse takip edebilirsin (\(followed.count)/\(Self.freeLimit)).")
                    }
                }
            }
        }
        .navigationTitle("Takip")
        .navigationDestination(for: String.self) { StockDetailView(ticker: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { tryAdd() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Hisse ekle")
            }
        }
        .alert("Hisse ekle", isPresented: $adding) {
            TextField("Sembol (örn. GARAN)", text: $newTicker)
                .textInputAutocapitalization(.characters)
            Button("Ekle", action: add)
            Button("Vazgeç", role: .cancel) { newTicker = "" }
        } message: {
            Text("BIST sembolünü gir. Bildirimler bu hisse için açılır.")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func tryAdd() {
        if !premium.isPremium && followed.count >= Self.freeLimit {
            showPaywall = true
        } else {
            adding = true
        }
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

    private func remove(at offsets: IndexSet) {
        for index in offsets { context.delete(followed[index]) }
    }
}

struct WatchRow: View {
    let stock: FollowedStock
    let nextDividend: Dividend?
    var info: StockInfo?

    var body: some View {
        HStack(spacing: 12) {
            TickerAvatar(ticker: stock.ticker, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.ticker).font(.headline)
                if let d = nextDividend {
                    Text("Temettü \(TRFormat.relativeDays(to: d.exDateValue).lowercased()) • \(TRFormat.date(d.exDateValue))")
                        .font(.caption)
                        .foregroundStyle(Brand.accent)
                } else {
                    Text("Yaklaşan temettü yok")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let last = info?.lastClose {
                    Text(TRFormat.perShare(last))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if let chg = info?.changePct {
                        Text("\(chg >= 0 ? "+" : "")\(TRFormat.percent(chg))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(chg >= 0 ? Brand.positive : Brand.negative)
                    }
                } else if let d = nextDividend {
                    Text(TRFormat.perShare(d.netPerShare))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
