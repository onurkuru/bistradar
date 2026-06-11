import SwiftUI
import SwiftData

enum AppTab: Hashable { case dividends, ipo, watch, settings }

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(FeedService.self) private var feed
    @Query private var prefs: [AppPrefs]
    @Query private var followed: [FollowedStock]

    @State private var tab: AppTab = .dividends
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                Brand.screen.ignoresSafeArea()

                Group {
                    switch tab {
                    case .dividends: DividendListView()
                    case .ipo: IPOListView()
                    case .watch: WatchlistView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                FloatingTabBar(selection: $tab)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { StockDetailView(ticker: $0) }
        }
        .tint(Brand.accent)
        .onAppear(perform: ensurePrefs)
        .onChange(of: feed.feed) { rescheduleNotifications() }
    }

    private func ensurePrefs() { if prefs.isEmpty { context.insert(AppPrefs()) } }

    private func rescheduleNotifications() {
        let pref = prefs.first ?? AppPrefs()
        let tickers = Set(followed.map(\.ticker))
        Task {
            await NotificationService.reschedule(
                feed: feed.feed, followedTickers: tickers,
                notifyAllIPOs: pref.notifyAllIPOs, daysBefore: pref.remindDaysBefore)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private let items: [(AppTab, String, String)] = [
        (.dividends, "calendar.badge.clock", "Temettü"),
        (.ipo, "sparkles", "Halka Arz"),
        (.watch, "star", "Takip"),
        (.settings, "gearshape", "Ayarlar"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { item in
                let on = selection == item.0
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = item.0 }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: on && item.0 == .watch ? "star.fill" : item.1)
                            .font(.system(size: 21, weight: on ? .semibold : .regular))
                        Text(item.2).manrope(11, .bold)
                    }
                    .foregroundStyle(on ? Brand.accent : Brand.ink3)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Brand.ink.opacity(0.04), lineWidth: 1))
        .shadow(color: Brand.ink.opacity(0.16), radius: 18, y: 8)
        .padding(.bottom, 6)
    }
}

#Preview {
    RootView()
        .environment(FeedService())
        .modelContainer(for: [FollowedStock.self, AppPrefs.self], inMemory: true)
}
