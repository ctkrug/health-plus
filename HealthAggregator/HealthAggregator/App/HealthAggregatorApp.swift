import SwiftUI
import HealthKit
import BackgroundTasks
import UserNotifications

@main
struct HealthAggregatorApp: App {
    @State private var appState = AppState()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.healthaggregator.app.whoopRefresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false); return
            }
            handleWhoopRefresh(task: refreshTask)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.healthaggregator.app.healthkitSync",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false); return
            }
            handleHealthKitSync(task: processingTask)
        }
    }

    private func handleWhoopRefresh(task: BGAppRefreshTask) {
        scheduleWhoopRefresh()
        Task {
            do {
                try await appState.whoopService.refreshIfNeeded()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }

    private func handleHealthKitSync(task: BGProcessingTask) {
        Task {
            await appState.healthKitService.performBackgroundSync()
            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleWhoopRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.healthaggregator.app.whoopRefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "healthaggregator" else { return }
        if url.host == "whoop" && url.path == "/callback" {
            Task {
                try? await appState.whoopService.handleCallback(url: url)
            }
        }
    }
}

@Observable
final class AppState {
    var healthKitService = HealthKitService()
    var whoopService = WhoopService()
    var workoutStore = WorkoutStore()
    var notificationService = NotificationService()
    var habitStore = HabitStore()
    var authService = AuthService()

    // Stored var so @Observable tracks mutations and re-renders RootView
    var isOnboardingComplete: Bool = UserDefaults.standard.bool(forKey: "onboardingComplete") {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "onboardingComplete") }
    }
}
