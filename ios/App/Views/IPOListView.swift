import SwiftUI

struct IPOListView: View {
    @Environment(FeedService.self) private var feed

    private var ipos: [IPO] {
        feed.feed.ipos.sorted { ($0.keyDate ?? .distantPast) > ($1.keyDate ?? .distantPast) }
    }

    var body: some View {
        List {
            if ipos.isEmpty {
                ContentUnavailableView(
                    "Şu an açık halka arz yok",
                    systemImage: "sparkles",
                    description: Text("Yeni halka arz bildirimi geldiğinde burada listelenir. Bildirim için Ayarlar’dan halka arz uyarısını aç.")
                )
            } else {
                ForEach(ipos) { ipo in
                    IPORow(ipo: ipo)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Halka Arz")
        .refreshable { await feed.refresh() }
    }
}

struct IPORow: View {
    let ipo: IPO
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ipo.ticker.isEmpty ? ipo.company : ipo.ticker)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(ipo.statusKind.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            if !ipo.ticker.isEmpty {
                Text(ipo.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let start = FeedDate.parse(ipo.subscriptionStart) {
                Label {
                    Text("Talep toplama: \(TRFormat.date(start))" +
                         (FeedDate.parse(ipo.subscriptionEnd).map { " – \(TRFormat.date($0))" } ?? ""))
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
            }

            if ipo.priceMin != nil || ipo.priceFixed != nil {
                Label(priceText, systemImage: "tag")
                    .font(.caption)
            }

            Button {
                if let url = URL(string: ipo.sourceUrl) { openURL(url) }
            } label: {
                Label("KAP bildirimini aç", systemImage: "doc.text")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    private var priceText: String {
        if let fixed = ipo.priceFixed { return "Fiyat: \(TRFormat.money(fixed))" }
        if let lo = ipo.priceMin, let hi = ipo.priceMax {
            return "Fiyat: \(TRFormat.money(lo)) – \(TRFormat.money(hi))"
        }
        if let lo = ipo.priceMin { return "Fiyat: \(TRFormat.money(lo))" }
        return "—"
    }

    private var statusColor: Color {
        switch ipo.statusKind {
        case .collecting: return .orange
        case .upcoming: return .blue
        case .listed: return .green
        case .draft: return .secondary
        }
    }
}
