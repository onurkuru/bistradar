import SwiftUI

// Ad slot. Hidden for Premium users. Until the Google Mobile Ads SDK is added
// (AdMob account + ad unit IDs), this renders a tasteful house promo that also
// upsells Premium — so the layout is final and dropping in the real banner later
// is a one-view swap (replace `placeholder` with the GADBannerView wrapper).
//
// AdMob integration steps (when ready):
//   1. Add GoogleMobileAds via SPM, set GADApplicationIdentifier in Info.plist.
//   2. Replace `placeholder` with a UIViewRepresentable wrapping GADBannerView
//      using AdConfig.bannerUnitID.
//   3. Call GADMobileAds.sharedInstance().start() at launch.
enum AdConfig {
    // Google's official test banner unit; swap for your real unit before release.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
}

struct AdBanner: View {
    @Environment(PremiumStore.self) private var premium
    var onUpgrade: () -> Void = {}

    var body: some View {
        if !premium.isPremium {
            placeholder
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(Brand.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .screenPadding()
                .padding(.bottom, 6)
        }
    }

    private var placeholder: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Brand.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reklamsız kullan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Premium ile reklamları kaldır")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Yükselt")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Brand.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
}
