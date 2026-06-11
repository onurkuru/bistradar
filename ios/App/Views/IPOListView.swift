import SwiftUI

struct IPOListView: View {
    @Environment(FeedService.self) private var feed
    @State private var showPaywall = false

    private var ipos: [IPO] {
        feed.feed.ipos.sorted { ($0.keyDate ?? .distantPast) > ($1.keyDate ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if ipos.isEmpty {
                    ContentUnavailableView(
                        "Şu an açık halka arz yok",
                        systemImage: "sparkles",
                        description: Text("Yeni halka arz bildirimi geldiğinde burada listelenir. Bildirim için Ayarlar’dan halka arz uyarısını aç.")
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(Array(ipos.enumerated()), id: \.element.id) { index, ipo in
                        IPOCard(ipo: ipo).screenPadding()
                        if index == 1 { AdBanner { showPaywall = true } }
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .background(Brand.bg)
        .navigationTitle("Halka Arz")
        .refreshable { await feed.refresh() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

struct IPOCard: View {
    let ipo: IPO
    @Environment(\.openURL) private var openURL

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TickerAvatar(ticker: ipo.ticker.isEmpty ? ipo.company : ipo.ticker, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ipo.ticker.isEmpty ? ipo.company : ipo.ticker)
                            .font(.headline)
                            .lineLimit(1)
                        if !ipo.ticker.isEmpty {
                            Text(ipo.company)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Pill(text: ipo.statusKind.label, color: statusColor)
                }

                if FeedDate.parse(ipo.subscriptionStart) != nil || ipo.priceMin != nil || ipo.priceFixed != nil {
                    Divider()
                }

                if let start = FeedDate.parse(ipo.subscriptionStart) {
                    infoRow("calendar", "Talep toplama",
                            TRFormat.date(start) + (FeedDate.parse(ipo.subscriptionEnd).map { " – \(TRFormat.date($0))" } ?? ""))
                }
                if ipo.priceMin != nil || ipo.priceFixed != nil {
                    infoRow("tag", "Fiyat", priceText)
                }

                Button {
                    if let url = URL(string: ipo.sourceUrl) { openURL(url) }
                } label: {
                    Label("KAP bildirimini aç", systemImage: "doc.text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(.secondary).frame(width: 16)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.medium))
        }
    }

    private var priceText: String {
        if let fixed = ipo.priceFixed { return TRFormat.money(fixed) }
        if let lo = ipo.priceMin, let hi = ipo.priceMax { return "\(TRFormat.money(lo)) – \(TRFormat.money(hi))" }
        if let lo = ipo.priceMin { return TRFormat.money(lo) }
        return "—"
    }

    private var statusColor: Color {
        switch ipo.statusKind {
        case .collecting: return Brand.accent
        case .upcoming: return .blue
        case .listed: return Brand.positive
        case .draft: return .secondary
        }
    }
}
