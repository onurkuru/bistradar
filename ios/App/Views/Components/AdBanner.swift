import SwiftUI
import GoogleMobileAds

// AdMob configuration for "Arz Radar" (publisher pub-4124204377269696).
// App ID  (in Info.plist/GADApplicationIdentifier): ca-app-pub-4124204377269696~3084694454
//
// Debug builds serve Google's TEST banner — clicking your own live ads risks an
// AdMob policy strike. Release builds use the real "Liste Banner" unit.
enum AdConfig {
    static let publisherID = "pub-4124204377269696"

    /// Google's official test banner unit — safe in debug.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    /// Real "Liste Banner" unit, used in release.
    static let productionBannerUnitID = "ca-app-pub-4124204377269696/9420173524"

    static var bannerUnitID: String {
        #if DEBUG
        return testBannerUnitID
        #else
        return productionBannerUnitID
        #endif
    }

    static func start() {
        MobileAds.shared.start(completionHandler: nil)
    }
}

/// SwiftUI wrapper around a standard AdMob banner. Sizes itself to 320×50.
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = Self.rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

/// Banner slot shown to free users; hidden for Premium. Upgrading to remove ads
/// is offered in Settings and the watchlist.
struct AdBanner: View {
    @Environment(PremiumStore.self) private var premium

    var body: some View {
        if !premium.isPremium {
            BannerAdView(adUnitID: AdConfig.bannerUnitID)
                .frame(width: 320, height: 50)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
    }
}
