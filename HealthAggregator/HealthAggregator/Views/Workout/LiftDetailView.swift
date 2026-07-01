import SwiftUI

/// Which value the lift chart plots. Estimated 1RM is the default — it stays comparable across
/// rep-range changes, unlike raw top weight.
enum LiftMetric: String, CaseIterable {
    case estimated1RM = "Est. 1RM"
    case topWeight = "Top Weight"
    case volume = "Volume"
}

/// Per-lift equivalent of `MetricDetailView`: an exercise picker (searchable — the library has
/// 60+ exercises), the same 1W/30D/90D/1Y period control, and the same interactive scrubber chart,
/// with PRs marked. Reuses `ChartPeriod` from MetricDetailView.swift and `InteractiveTrendChart`.
struct LiftDetailView: View {
    let allExerciseNames: [String]
    let sessions: [WorkoutSession]
    @State private var selectedExercise: String
    @State private var metric: LiftMetric = .estimated1RM
    @State private var period: ChartPeriod = .quarter
    @State private var searchText = ""
    @State private var showPicker = false

    init(exerciseName: String, allExerciseNames: [String], sessions: [WorkoutSession]) {
        self.allExerciseNames = allExerciseNames
        self.sessions = sessions
        _selectedExercise = State(initialValue: exerciseName)
    }

    private var points: [LiftDataPoint] {
        LiftHistory.points(for: selectedExercise, in: sessions)
    }

    private var displayed: [LiftDataPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: Date())!
        return points.filter { $0.date >= cutoff }
    }

    private var chartPoints: [(Date, Double)] {
        displayed.map { ($0.date, value(for: $0)) }
    }

    private var current: Double? {
        points.last.map(value(for:))
    }

    private var stats: (avg: Double, min: Double, max: Double)? {
        guard !displayed.isEmpty else { return nil }
        let vals = displayed.map(value(for:))
        return (vals.reduce(0, +) / Double(vals.count), vals.min()!, vals.max()!)
    }

    private var unit: String { metric == .volume ? "lb·reps" : "lb" }

    private func value(for point: LiftDataPoint) -> Double {
        switch metric {
        case .estimated1RM: return point.estimated1RM / 0.453592
        case .topWeight: return point.topWeightKg / 0.453592
        case .volume: return point.totalVolume / 0.453592
        }
    }

    private func format(_ v: Double) -> String {
        Int(v.rounded()).formatted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                exercisePicker
                heroSection
                if points.isEmpty {
                    noDataSection
                } else {
                    metricPicker
                    periodPicker
                    chartSection
                    if let s = stats { statsRow(s) }
                }
                Spacer().frame(height: 50)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(selectedExercise)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) { exerciseSearchSheet }
    }

    // MARK: - Exercise switcher

    private var exercisePicker: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentBlue)
                Text("Showing \(selectedExercise)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 0.5))
        }
        .padding(.top, 12)
    }

    private var exerciseSearchSheet: some View {
        NavigationStack {
            List {
                ForEach(filteredNames, id: \.self) { name in
                    Button {
                        selectedExercise = name
                        showPicker = false
                    } label: {
                        HStack {
                            Text(name).foregroundStyle(Color.textPrimary)
                            Spacer()
                            if name == selectedExercise {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentBlue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Choose a Lift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPicker = false }
                }
            }
        }
    }

    private var filteredNames: [String] {
        guard !searchText.isEmpty else { return allExerciseNames }
        return allExerciseNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            Group {
                if let v = current {
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(format(v))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Text(unit)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.bottom, 4)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.top, 18)

            Text("Most Recent")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, 22)
        }
    }

    private var metricPicker: some View {
        HStack(spacing: 0) {
            ForEach(LiftMetric.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { metric = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(metric == m ? Color.accentBlue : Color.clear)
                        .foregroundStyle(metric == m ? .white : Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(ChartPeriod.allCases, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { period = p }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(period == p ? Color.accentBlue : Color.clear)
                        .foregroundStyle(period == p ? .white : Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .padding(4)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var chartSection: some View {
        if chartPoints.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.textTertiary)
                Text("No data for this period")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hold and drag to scrub")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
                InteractiveTrendChart(
                    points: chartPoints,
                    color: .accentBlue,
                    unit: unit,
                    valueFormat: format,
                    weekdayLabels: period == .week,
                    yDomainPadding: yPadding,
                    height: 220
                )
                if displayed.contains(where: \.isPR) {
                    Label("🔥 marks a PR set", systemImage: "star.fill")
                        .labelStyle(.titleOnly)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentYellow)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var yPadding: Double {
        guard let s = stats, s.max > s.min else { return 1 }
        return (s.max - s.min) * 0.15
    }

    private func statsRow(_ s: (avg: Double, min: Double, max: Double)) -> some View {
        HStack(spacing: 12) {
            LiftStatBlock(label: "Average", value: format(s.avg), unit: unit, color: .accentBlue)
            LiftStatBlock(label: "Lowest", value: format(s.min), unit: unit, color: .accentRed)
            LiftStatBlock(label: "Highest", value: format(s.max), unit: unit, color: .accentGreen)
        }
        .padding(.horizontal, 20)
    }

    private var noDataSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 20)
            Text("No logged sets for \(selectedExercise) yet.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LiftStatBlock: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 0.5))
    }
}

// MARK: - Reusable navigation link

/// Wraps any label in a tap target that opens `LiftDetailView` focused on `exerciseName`.
/// Use inside a NavigationStack.
struct LiftNavLink<Label: View>: View {
    @Environment(AppState.self) private var appState
    let exerciseName: String
    @ViewBuilder var label: () -> Label

    var body: some View {
        NavigationLink {
            LiftDetailView(
                exerciseName: exerciseName,
                allExerciseNames: LiftHistory.trainedExerciseNames(in: appState.workoutStore.sessions),
                sessions: appState.workoutStore.sessions
            )
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }
}
