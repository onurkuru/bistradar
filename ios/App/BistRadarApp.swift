import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct BistRadarApp: App {
    @State private var feedService = FeedService()
    private let refreshID = "com.onurkuru.bistradar.refresh"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(feedService)
                .onAppear {
                    feedService.loadInitial()
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
