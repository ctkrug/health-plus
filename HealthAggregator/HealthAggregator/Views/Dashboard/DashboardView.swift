import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) var appState
    @State private var showSettings = false
    @AppStorage("dashboardCardOrder") private var cardOrderData: Data = (try? JSONEncoder().encode(DashboardCard.defaultOrder)) ?? Data()
    @State private var cardOrder: [DashboardCard] = DashboardCard.defaultOrder

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(cardOrder) { card in
                            cardView(for: card)
                                .padding(.horizontal, 16)
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    await appState.healthKitService.refresh()
                    await appState.whoopService.refresh()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").fabStyle(primary: false, diameter: 46)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 14)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                AppHeader(subtitle: Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView()
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

enum DashboardCard: String, CaseIterable, Identifiable, Codable {
    case recovery, activity, body, nutrition, sleep, steps, workout
    var id: String { rawValue }

    static let defaultOrder: [DashboardCard] = [.recovery, .activity, .steps, .body, .nutrition, .sleep, .workout]
}
