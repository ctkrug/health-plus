import SwiftUI
import HealthKit
import BackgroundTasks
import UserNotifications

@main
struct HealthAggregatorApp: App {
    @State private var appState = AppState()
    @AppStorage("appTheme") private var appTheme = AppTheme.midnight.rawValue

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(AppTheme(rawValue: appTheme)?.scheme)
                // Re-key on theme change so every semantic color token re-resolves app-wide.
                .id(appTheme)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.ctkrug.healthplus.whoopRefresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false); return
            }
            handleWhoopRefresh(task: refreshTask)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.ctkrug.healthplus.healthkitSync",
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
        let workTask = Task {
            do {
                try await appState.whoopService.refreshIfNeeded()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func handleHealthKitSync(task: BGProcessingTask) {
        let workTask = Task {
            await appState.healthKitService.performBackgroundSync()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func scheduleWhoopRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.ctkrug.healthplus.whoopRefresh")
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
    var profileStore = ProfileStore()

    init() {
        // One-time install of Charlie's 12-Week Build program + its daily habits. Each is flag-gated
        // and idempotent. Done here (the composition root) rather than in the stores' inits so the
        // WorkoutStore/HabitStore unit tests keep seeing vanilla seeded state.
        workoutStore.installCharlieBuildIfNeeded()
        habitStore.installCharlieBuildHabitsIfNeeded()
    }

    /// App-lock gate. Lives here (not in a view) so it survives the theme-driven RootView rebuild.
    var isUnlocked = false

    // Stored var so @Observable tracks mutations and re-renders RootView
    var isOnboardingComplete: Bool = UserDefaults.standard.bool(forKey: "onboardingComplete") {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "onboardingComplete") }
    }
}
