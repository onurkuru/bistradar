import SwiftUI
import SwiftData

struct StockDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Query private var followed: [FollowedStock]
    let ticker: String

    private var history: [Dividend] {
        feed.feed.dividends
            .filter { $0.ticker == ticker }
            .sorted { ($0.exDateValue ?? .distantPast) > ($1.exDateValue ?? .distantPast) }
    }

    private var isFollowed: Bool { followed.contains { $0.ticker == ticker } }

    private var upcoming: Dividend? {
        DividendCalendar.upcoming(history).first
    }

    var body: some View {
        List {
            if let next = upcoming {
                Section("Yaklaşan temettü") {
                    LabeledContent("Hak kullanım", value: TRFormat.date(next.exDateValue))
                    LabeledContent("Kalan", value: TRFormat.relativeDays(to: next.exDateValue))
                    LabeledContent("Net / pay", value: TRFormat.perShare(next.netPerShare))
                    LabeledContent("Brüt / pay", value: TRFormat.perShare(next.grossPerShare))
                    LabeledContent("Verim", value: TRFormat.percent(next.yieldPct))
                }
            }

            Section("Geçmiş temettüler") {
                if history.isEmpty {
                    Text("Bu hisse için kayıt yok.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { d in
                        HStack {
                            Text(TRFormat.date(d.exDateValue))
                                .font(.subheadline)
                            Spacer()
                            Text(TRFormat.perShare(d.netPerShare))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                            if d.yieldPct != nil {
                                Text(TRFormat.percent(d.yieldPct))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .frame(width: 56, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            Section {
                Link(destination: URL(string: history.first?.sourceUrl
                    ?? "https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/sirket-karti.aspx?hisse=\(ticker)")!) {
                    Label("İş Yatırım şirket kartı", systemImage: "link")
                }
            } footer: {
                Text("Veri İş Yatırım ve KAP kaynaklıdır. Yatırım tavsiyesi değildir.")
            }
        }
        .navigationTitle(ticker)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFollow()
                } label: {
                    Image(systemName: isFollowed ? "star.fill" : "star")
                        .foregroundStyle(isFollowed ? .yellow : .secondary)
                }
                .accessibilityLabel(isFollowed ? "Takipten çıkar" : "Takip et")
            }
        }
    }

    private func toggleFollow() {
        if let existing = followed.first(where: { $0.ticker == ticker }) {
            context.delete(existing)
        } else {
            context.insert(FollowedStock(ticker: ticker))
        }
    }
}
