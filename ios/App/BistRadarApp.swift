import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct BistRadarApp: App {
    @State private var feedService = FeedService()
    @State private var premium = PremiumStore()
    private let refreshID = "com.onurkuru.bistradar.refresh"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(feedService)
                .environment(premium)
                .tint(Brand.accent)
                .onAppear {
                    feedService.loadInitial()
                    premium.start()
                    AdConfig.start()
                    registerBackgroundTask()
                    scheduleRefresh()
                }
        }
        .modelContainer(for: [FollowedStock.self, AppPrefs.self])
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) { task in
            Task {
                await feedService.refresh()
                scheduleRefresh()
                task.setTaskCompleted(success: feedService.lastError == nil)
            }
        }
    }

    private func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
