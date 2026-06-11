import SwiftUI

struct PaywallView: View {
    @Environment(PremiumStore.self) private var premium
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Brand.accent)
                        Text("BIST Radar Premium")
                            .font(.title.weight(.bold))
                        Text("Tek seferlik ödeme. Abonelik yok.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 28)

                    Card {
                        VStack(alignment: .leading, spacing: 18) {
                            feature("rectangle.slash", "Reklamsız", "Tüm reklamlar kalkar.")
                            feature("star.fill", "Sınırsız takip", "İstediğin kadar hisse takip et.")
                            feature("bell.badge.fill", "Öncelikli bildirim", "Temettü ve halka arz uyarıları.")
                            feature("heart.fill", "Geliştiriciyi destekle", "Bağımsız, tek kişilik proje.")
                        }
                    }
                    .screenPadding()
                }
            }
            .background(Brand.bg)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { await premium.purchase(); if premium.isPremium { dismiss() } }
                    } label: {
                        Group {
                            if premium.isPurchasing { ProgressView().tint(.white) }
                            else if let p = premium.product { Text("Premium’a geç — \(p.displayPrice)") }
                            else { Text("Premium’a geç") }
                        }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(Brand.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(premium.isPurchasing || premium.product == nil)

                    Button("Satın alımları geri yükle") {
                        Task { await premium.restore(); if premium.isPremium { dismiss() } }
                    }
                    .font(.footnote)
                }
                .screenPadding()
                .padding(.bottom, 8)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Brand.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
