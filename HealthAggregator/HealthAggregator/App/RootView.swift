import SwiftUI

struct RootView: View {
    @Environment(AppState.self) var appState
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

            NutritionView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(4)
        }
        .tint(Color.accentBlue)
    }
}
