import SwiftUI

struct NutritionView: View {
    @Environment(AppState.self) var appState
    @State private var showWaterAlert = false
    @State private var customWater = ""

    var hk: HealthKitService { appState.healthKitService }
    private var calProgress: Double { min(hk.caloriesConsumed / max(hk.calorieGoal, 1), 1.0) }
    private var proteinGoal: Double { 180 }  // stored in settings ideally
    private var waterGoal: Double { 2800 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Main calorie ring
                        CalorieRingCard(consumed: hk.caloriesConsumed, goal: hk.calorieGoal)
                            .padding(.horizontal, 16)

                        // Macro breakdown
                        MacroBreakdownCard(hk: hk, proteinGoal: proteinGoal)
                            .padding(.horizontal, 16)

                        // Water tracker
                        WaterTrackerCard(waterMl: hk.waterMl, goal: waterGoal) { amount in
                            Task { try? await hk.addWater(ml: amount) }
                        }
                        .padding(.horizontal, 16)

                        // No data banner
                        if hk.caloriesConsumed == 0 {
                            MFPSetupCard()
                                .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Calorie Ring

struct CalorieRingCard: View {
    let consumed: Double
    let goal: Double

    private var remaining: Double { goal - consumed }
    private var progress: Double { min(consumed / max(goal, 1), 1.0) }
    private var overGoal: Bool { consumed > goal }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    RingView(progress: progress, color: overGoal ? .accentRed : .accentGreen, lineWidth: 14, diameter: 110)
                    VStack(spacing: 2) {
                        Text("\(Int(consumed))")
                            .font(.metric(30))
                            .foregroundStyle(overGoal ? Color.accentRed : Color.textPrimary)
                        Text("kcal")
                            .font(.metricLabel(12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    CalorieStatRow(label: "Goal", value: "\(Int(goal))", unit: "kcal", color: .textSecondary)
                    CalorieStatRow(label: overGoal ? "Over" : "Remaining", value: "\(Int(abs(remaining)))", unit: "kcal",
                                  color: overGoal ? .accentRed : .accentGreen)
                    CalorieStatRow(label: "Burned", value: "\(Int(goal + abs(remaining)))", unit: "estimated", color: .textSecondary)
                }
                Spacer()
            }
        }
        .card()
    }
}

struct CalorieStatRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.metricLabel(13)).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value).font(.metric(16)).foregroundStyle(color)
            Text(unit).font(.metricLabel(11)).foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Macro Breakdown

struct MacroBreakdownCard: View {
    let hk: HealthKitService
    let proteinGoal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macros")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 12) {
                MacroProgressRow(label: "Protein", grams: hk.proteinGrams, goal: proteinGoal, color: .accentBlue)
                MacroProgressRow(label: "Carbs", grams: hk.carbGrams, goal: 250, color: .accentYellow)
                MacroProgressRow(label: "Fat", grams: hk.fatGrams, goal: 80, color: .accentOrange)
                MacroProgressRow(label: "Fiber", grams: hk.fiberGrams, goal: 30, color: .accentGreen)
            }
        }
        .card()
    }
}

struct MacroProgressRow: View {
    let label: String
    let grams: Double
    let goal: Double
    let color: Color

    private var progress: Double { min(grams / max(goal, 1), 1.0) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.metricLabel(13))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(grams))")
                        .font(.metric(15))
                        .foregroundStyle(Color.textPrimary)
                    Text("/ \(Int(goal))g")
                        .font(.metricLabel(11))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.cardBorder)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.6), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Water Tracker

struct WaterTrackerCard: View {
    let waterMl: Double
    let goal: Double
    let onAdd: (Double) -> Void

    private var progress: Double { min(waterMl / max(goal, 1), 1.0) }
    private var waterOz: Double { waterMl / 29.5735 }
    private var goalOz: Double { goal / 29.5735 }

    let quickAmounts: [(String, Double)] = [
        ("8 oz", 236), ("12 oz", 355), ("16 oz", 473), ("24 oz", 710)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Hydration", systemImage: "drop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", waterOz))
                        .font(.metric(20))
                        .foregroundStyle(Color.accentBlue)
                    Text("/ \(Int(goalOz)) oz")
                        .font(.metricLabel(12))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Progress bar (wave-like)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.cardBorder)
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentBlue.gradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.6), value: progress)
                }
            }
            .frame(height: 12)

            // Quick add buttons
            HStack(spacing: 8) {
                ForEach(quickAmounts, id: \.0) { item in
                    Button {
                        onAdd(item.1)
                        HapticsManager.light()
                    } label: {
                        Text(item.0)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
        }
        .card()
    }
}

// MARK: - MFP Setup

struct MFPSetupCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.accentBlue)
                Text("Connect MyFitnessPal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            Text("To see nutrition data, enable Health sync in MyFitnessPal:")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(mfpSteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentBlue)
                            .padding(.top, 2)
                        Text(step)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .card()
    }

    private let mfpSteps = [
        "Open MyFitnessPal → Profile → Settings",
        "Tap \"Apps & Devices\" → Apple Health",
        "Enable \"Nutrition Data\" and \"Calories\"",
        "Come back and pull to refresh"
    ]
}
