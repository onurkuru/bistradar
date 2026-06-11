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
                            .font(.system(size: 52)).foregroundStyle(Brand.accent)
                        Text("Arz Radar Premium").manrope(24, .heavy)
                        Text("Tek seferlik ödeme. Abonelik yok.")
                            .manrope(14, .medium).foregroundStyle(Brand.ink2)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 18) {
                        feature("rectangle.slash", "Reklamsız", "Tüm reklamlar kalkar.")
                        feature("star.fill", "Sınırsız takip", "İstediğin kadar hisse takip et.")
                        feature("bell.badge.fill", "Öncelikli bildirim", "Temettü ve halka arz uyarıları.")
                        feature("heart.fill", "Geliştiriciyi destekle", "Bağımsız, tek kişilik proje.")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Brand.line, lineWidth: 1))
                    .screenPadding()
                }
            }
            .background(Brand.section)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { await premium.purchase(); if premium.isPremium { dismiss() } }
                    } label: {
                        Group {
                            if premium.isPurchasing { ProgressView().tint(.white) }
                            else if let p = premium.product { Text("Premium’a geç — \(p.displayPrice)").manrope(16, .bold) }
                            else { Text("Premium’a geç").manrope(16, .bold) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(minHeight: 52)
                        .background(Brand.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(premium.isPurchasing || premium.product == nil)

                    Button("Satın alımları geri yükle") {
                        Task { await premium.restore(); if premium.isPremium { dismiss() } }
                    }
                    .manrope(13, .semibold).foregroundStyle(Brand.ink2)
                }
                .screenPadding().padding(.bottom, 8)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.ink3)
                    }
                }
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Brand.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).manrope(16, .bold)
                Text(detail).manrope(13, .medium).foregroundStyle(Brand.ink2)
            }
        }
    }
}
