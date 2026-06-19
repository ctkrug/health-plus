import SwiftUI

struct RootView: View {
    @Environment(AppState.self) var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        if !appState.isOnboardingComplete {
            OnboardingView()
        } else {
            MainTabView(selectedTab: $selectedTab)
                .task {
                    await appState.healthKitService.requestAuthorization()
                    await appState.notificationService.requestAuthorization()
                    guard appState.notificationService.isAuthorized else { return }
                    appState.notificationService.scheduleDailySummary()
                    appState.notificationService.scheduleWeeklyRecap()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    // Refresh stale data and re-validate the Apple ID when returning to the app
                    Task {
                        await appState.healthKitService.refresh()
                        await appState.whoopService.refresh()
                        await appState.authService.checkCredentialState()
                    }
                }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)

            WorkoutListView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
                .tag(1)

            BodyCompositionView()
                .tabItem {
                    Label("Body", systemImage: "figure.stand")
                }
                .tag(2)

            RecoveryView()
                .tabItem {
                    Label("Recovery", systemImage: "heart.fill")
                }
                .tag(3)

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle.fill")
                }
                .tag(4)
        }
        .tint(Color.accentBlue)
    }
}
