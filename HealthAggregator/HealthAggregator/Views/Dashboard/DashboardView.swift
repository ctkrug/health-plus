import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) var appState
    @State private var isRefreshing = false
    @State private var showSettings = false
    @State private var editMode = false
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
                        Spacer().frame(height: 20)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    isRefreshing = true
                    await appState.healthKitService.refresh()
                    await appState.whoopService.refresh()
                    isRefreshing = false
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
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
            RecoveryCard(whoop: appState.whoopService.snapshot, hk: appState.healthKitService)
        case .activity:
            ActivityRingsCard(hk: appState.healthKitService)
        case .body:
            BodySnapshotCard(hk: appState.healthKitService)
        case .nutrition:
            NutritionCard(hk: appState.healthKitService)
        case .sleep:
            SleepCard(hk: appState.healthKitService, whoop: appState.whoopService.snapshot)
        case .steps:
            StepsCard(hk: appState.healthKitService)
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
