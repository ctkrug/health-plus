import SwiftUI
import LocalAuthentication

struct RootView: View {
    @Environment(AppState.self) var appState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var selectedTab = 0

    private var locked: Bool { appLockEnabled && !appState.isUnlocked }

    var body: some View {
        Group {
            if !appState.isOnboardingComplete {
                OnboardingView()
            } else if locked {
                AppLockScreen { authenticate() }
            } else {
                MainTabView(selectedTab: $selectedTab)
                    .task {
                        await appState.healthKitService.requestAuthorization()
                        await appState.notificationService.requestAuthorization()
                        guard appState.notificationService.isAuthorized else { return }
                        appState.notificationService.scheduleDailySummary()
                        appState.notificationService.scheduleWeeklyRecap()
                        appState.checkMuscleBalanceAlert()
                    }
            }
        }
        .onAppear { if locked { authenticate() } }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if locked { authenticate() }
                // Refresh stale data and re-validate the Apple ID when returning to the app
                Task {
                    await appState.healthKitService.refresh()
                    await appState.whoopService.refresh()
                    await appState.authService.checkCredentialState()
                }
            case .background:
                // Re-lock when the app leaves the foreground
                if appLockEnabled { appState.isUnlocked = false }
            default:
                break
            }
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var error: NSError?
        // .deviceOwnerAuthentication = biometrics with automatic passcode fallback
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode set up — don't lock the user out of their own data
            appState.isUnlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock HealthSync") { success, _ in
            DispatchQueue.main.async {
                if success { appState.isUnlocked = true }
            }
        }
    }
}

// MARK: - Lock screen

struct AppLockScreen: View {
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.brand)
                VStack(spacing: 6) {
                    Text("HealthSync is locked")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    Text("Authenticate to view your health data")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button(action: onUnlock) {
                    Label("Unlock", systemImage: "faceid")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.brandStart.opacity(0.35), radius: 10, y: 4)
                }
                .padding(.horizontal, 40)
            }
            .padding(.horizontal, 24)
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

            HabitsView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle.fill")
                }
                .tag(3)
        }
        .tint(Color.accentBlue)
    }
}
