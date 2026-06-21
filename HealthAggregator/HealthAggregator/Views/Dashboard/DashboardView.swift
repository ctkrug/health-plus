import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) var appState
    @State private var showProfile = false
    @AppStorage("dashboardCardOrder") private var cardOrderData: Data = (try? JSONEncoder().encode(DashboardCard.defaultOrder)) ?? Data()
    @State private var cardOrder: [DashboardCard] = DashboardCard.defaultOrder

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ProfileSummaryCard { showProfile = true }
                            .padding(.horizontal, 16)

                        ForEach(cardOrder) { card in
                            cardView(for: card)
                                .padding(.horizontal, 16)
                        }
                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await appState.healthKitService.refresh()
                    await appState.whoopService.refresh()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader(subtitle: Date.now.formatted(.dateTime.weekday(.wide).month().day())) {
                    Button { showProfile = true } label: { ProfileAvatar() }
                        .buttonStyle(.plain)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .onAppear {
                if let decoded = try? JSONDecoder().decode([DashboardCard].self, from: cardOrderData) {
                    cardOrder = decoded
                }
            }
            .onChange(of: cardOrder) { _, newOrder in
                cardOrderData = (try? JSONEncoder().encode(newOrder)) ?? cardOrderData
            }
        }
    }

    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        switch card {
        case .recovery:
            RecoveryCard(whoop: appState.whoopService.snapshot, hk: appState.healthKitService,
                         isConnected: appState.whoopService.isConnected)
        case .activity:
            ActivityRingsCard(hk: appState.healthKitService)
        case .body:
            MetricNavLink(metricID: "weight") { BodySnapshotCard(hk: appState.healthKitService) }
        case .nutrition:
            MetricNavLink(metricID: "calories") { NutritionCard(hk: appState.healthKitService) }
        case .sleep:
            MetricNavLink(metricID: "sleep") { SleepCard(hk: appState.healthKitService, whoop: appState.whoopService.snapshot) }
        case .steps:
            MetricNavLink(metricID: "steps") { StepsCard(hk: appState.healthKitService) }
        case .workout:
            TodayWorkoutCard(store: appState.workoutStore)
        }
    }
}

// MARK: - Profile summary (Home header card → opens Profile + Settings)

struct ProfileSummaryCard: View {
    @Environment(AppState.self) var appState
    let onTap: () -> Void

    private var store: WorkoutStore { appState.workoutStore }
    private var name: String {
        let n = appState.authService.displayName
        return n.isEmpty ? "Athlete" : n.components(separatedBy: " ").first ?? n
    }
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ProfileAvatar(diameter: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Text(name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentOrange)
                    Text("\(store.streak.currentDays)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

enum DashboardCard: String, CaseIterable, Identifiable, Codable {
    case recovery, activity, body, nutrition, sleep, steps, workout
    var id: String { rawValue }

    static let defaultOrder: [DashboardCard] = [.recovery, .activity, .steps, .body, .nutrition, .sleep, .workout]
}
