import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Query private var prefs: [AppPrefs]
    @Query private var followed: [FollowedStock]

    var body: some View {
        TabView {
            NavigationStack { DividendListView() }
                .tabItem { Label("Temettü", systemImage: "turkishlirasign.circle.fill") }

            NavigationStack { IPOListView() }
                .tabItem { Label("Halka Arz", systemImage: "sparkles") }

            NavigationStack { WatchlistView() }
                .tabItem { Label("Takip", systemImage: "star.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
        }
        .onAppear(perform: ensurePrefs)
        .onChange(of: feed.feed) { rescheduleNotifications() }
    }

    private func ensurePrefs() {
        if prefs.isEmpty { context.insert(AppPrefs()) }
    }

    private func rescheduleNotifications() {
        let pref = prefs.first ?? AppPrefs()
        let tickers = Set(followed.map(\.ticker))
        Task {
            await NotificationService.reschedule(
                feed: feed.feed,
                followedTickers: tickers,
                notifyAllIPOs: pref.notifyAllIPOs,
                daysBefore: pref.remindDaysBefore
            )
        }
    }
}

#Preview {
    RootView()
        .environment(FeedService())
        .modelContainer(for: [FollowedStock.self, AppPrefs.self], inMemory: true)
}
