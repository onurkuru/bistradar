import SwiftUI

struct IPOListView: View {
    @Environment(FeedService.self) private var feed
    @State private var seg: Seg = .all

    enum Seg: Hashable { case all, upcoming, live, closed }

    private var ipos: [IPO] {
        let all = feed.feed.ipos.sorted { ($0.keyDate ?? .distantPast) > ($1.keyDate ?? .distantPast) }
        switch seg {
        case .all: return all
        case .upcoming: return all.filter { $0.statusKind == .upcoming || $0.statusKind == .draft }
        case .live: return all.filter { $0.statusKind == .collecting }
        case .closed: return all.filter { $0.statusKind == .listed }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Halka Arz").manrope(30, .heavy)
                    .padding(.horizontal, 6).padding(.top, 6)

                UnderlineTabs(selection: $seg, options: [
                    (.all, "Tümü"), (.upcoming, "Yaklaşan"), (.live, "Sürüyor"), (.closed, "Tamamlandı"),
                ])
                .padding(.horizontal, 6)

                if ipos.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        ForEach(ipos) { IPOCard(ipo: $0) }
                    }
                }
            }
            .screenPadding()
            .padding(.bottom, 120)
        }
        .background(Brand.screen)
        .refreshable { await feed.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Brand.ink3)
            Text("Şu an açık halka arz yok").manrope(16, .bold)
            Text("Yeni halka arz bildirimi geldiğinde burada listelenir.")
                .manrope(13, .medium).foregroundStyle(Brand.ink3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 50)
    }
}

struct IPOCard: View {
    let ipo: IPO
    @Environment(\.openURL) private var openURL

    private var statusChip: (String, ChipTone) {
        switch ipo.statusKind {
        case .upcoming, .draft: return ("Yaklaşan", .info)
        case .collecting: return ("Sürüyor", .pos)
        case .listed: return ("Tamamlandı", .mute)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                GradientAvatar(ticker: ipo.ticker.isEmpty ? ipo.company : ipo.ticker, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ipo.ticker.isEmpty ? "—" : ipo.ticker).manrope(17, .heavy)
                    Text(ipo.company).manrope(12.5, .semibold).foregroundStyle(Brand.ink3).lineLimit(1)
                }
                Spacer(minLength: 6)
                Chip(text: statusChip.0, tone: statusChip.1)
            }
            .padding(.bottom, 12)

            if priceText != nil {
                infoRow("Fiyat") { AnyView(MoneyText(value: priceValue, fraction: 2, suffix: nil, prefix: "₺", size: 15.5)) }
            }
            if let method = ipo.method {
                infoRow("Yöntem") { AnyView(Text(method).manrope(13.5, .semibold)) }
            }
            if let sub = subscriptionText {
                infoRow("Talep toplama") { AnyView(Text(sub).manrope(13.5, .semibold)) }
            }

            Button {
                if let url = URL(string: ipo.sourceUrl) { openURL(url) }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "doc.text").font(.system(size: 15, weight: .semibold))
                    Text("KAP bildirimini aç").manrope(14.5, .bold)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Brand.accent)
                .padding(.top, 13)
                .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Brand.card)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Brand.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Brand.ink.opacity(0.05), radius: 14, y: 6)
    }

    private func infoRow(_ label: String, @ViewBuilder value: () -> AnyView) -> some View {
        HStack {
            Text(label).manrope(14.5, .semibold).foregroundStyle(Brand.ink2)
            Spacer()
            value()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
    }

    private var priceValue: Double { ipo.priceFixed ?? ipo.priceMin ?? 0 }
    private var priceText: String? { (ipo.priceFixed != nil || ipo.priceMin != nil) ? "x" : nil }
    private var subscriptionText: String? {
        guard let start = FeedDate.parse(ipo.subscriptionStart) else { return nil }
        let end = FeedDate.parse(ipo.subscriptionEnd)
        return TRFormat.date(start) + (end.map { " – \(TRFormat.date($0))" } ?? "")
    }
}
