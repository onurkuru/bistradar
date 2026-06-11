import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Query(sort: \FollowedStock.addedAt) private var followed: [FollowedStock]
    @State private var adding = false
    @State private var newTicker = ""

    var body: some View {
        List {
            if followed.isEmpty {
                ContentUnavailableView {
                    Label("Takip listen boş", systemImage: "star")
                } description: {
                    Text("Takip ettiğin hisselerin temettü hak kullanım tarihleri yaklaşınca bildirim alırsın.")
                } actions: {
                    Button("Hisse Ekle") { adding = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(followed) { stock in
                    NavigationLink(value: stock.ticker) {
                        WatchRow(stock: stock, nextDividend: nextDividend(for: stock.ticker))
                    }
                }
                .onDelete(perform: remove)
            }
        }
        .navigationTitle("Takip")
        .navigationDestination(for: String.self) { StockDetailView(ticker: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Image(systemName: "plus") }
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.ticker)
                    .font(.headline)
                if let d = nextDividend {
                    Text("Temettü \(TRFormat.relativeDays(to: d.exDateValue).lowercased()) • \(TRFormat.date(d.exDateValue))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Yaklaşan temettü yok")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let d = nextDividend {
                Text(TRFormat.perShare(d.netPerShare))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}
