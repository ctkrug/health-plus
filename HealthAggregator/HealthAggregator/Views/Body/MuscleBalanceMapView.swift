import SwiftUI
import MuscleMap

/// Which lens colors the body diagram. Balance status (vs. this week's volume landmark) is the
/// default — "tells you where to focus." Volume heatmap is a simpler "what have I actually
/// trained" view with no target baked in.
enum MuscleHighlightMode: String, CaseIterable {
    case balance = "Balance"
    case volume = "Volume"
}

/// The interactive muscle map: a tappable front/back body diagram (rendered by the third-party
/// `MuscleMap` package — MIT-licensed, see docs/SPEC-lift-charts-and-muscle-map.md §2.3), the
/// Balance Index headline, antagonist-ratio safety checks, and a "Focus on:" recommendation strip.
/// Reached from a card on the Body tab.
struct MuscleBalanceMapView: View {
    @Environment(AppState.self) var appState
    @State private var side: BodySide = .front
    @State private var mode: MuscleHighlightMode = .balance
    @State private var selectedMuscle: Muscle? = nil

    private var store: WorkoutStore { appState.workoutStore }
    private var report: MuscleBalanceReport { MuscleBalanceEngine.balanceReport(sessions: store.sessions) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreHeader
                sideToggle
                bodyDiagram
                    .frame(height: 380)
                    .padding(.horizontal, 40)
                modeToggle
                legend
                if !report.antagonistPairs.isEmpty {
                    antagonistSection
                }
                if !report.recommendations.isEmpty {
                    focusSection
                }
                Spacer().frame(height: 30)
            }
            .padding(.top, 12)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Muscle Balance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMuscle) { muscle in
            NavigationStack {
                MuscleGroupDetailView(muscle: muscle, sessions: store.sessions)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var scoreHeader: some View {
        if let score = report.overallScore {
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(score))
                Text("BALANCE INDEX")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .tracking(1.5)
            }
        } else {
            VStack(spacing: 4) {
                Text("Gathering Data")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                Text("Keep logging workouts — this needs about 2 weeks of history to mean something.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 67...: return .accentGreen
        case 34..<67: return .accentYellow
        default: return .accentRed
        }
    }

    // MARK: - Controls

    private var sideToggle: some View {
        Picker("Side", selection: $side) {
            Text("Front").tag(BodySide.front)
            Text("Back").tag(BodySide.back)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 60)
    }

    private var modeToggle: some View {
        Picker("Highlight", selection: $mode) {
            ForEach(MuscleHighlightMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 60)
    }

    // MARK: - Diagram

    @ViewBuilder
    private var bodyDiagram: some View {
        switch mode {
        case .balance: balanceBodyView
        case .volume: volumeBodyView
        }
    }

    private var balanceBodyView: some View {
        var view = BodyView(gender: .male, side: side)
        for balance in report.perMuscle where balance.status != .noData {
            view = view.highlight(balance.group, color: statusColor(balance.status))
        }
        return view
            .selected(selectedMuscle)
            .onMuscleSelected { muscle, _ in
                HapticsManager.selection()
                selectedMuscle = muscle
            }
    }

    private var volumeBodyView: some View {
        let volumes = MuscleBalanceEngine.weeklyVolume(sessions: store.sessions)
        let intensities: [MuscleIntensity] = report.perMuscle.compactMap { balance in
            guard balance.mrv > 0 else { return nil }
            let sets = volumes[balance.group] ?? 0
            guard sets > 0 else { return nil }
            return MuscleIntensity(muscle: balance.group, intensity: min(sets / balance.mrv, 1.0))
        }
        return BodyView(gender: .male, side: side)
            .heatmap(intensities, colorScale: .workout)
            .selected(selectedMuscle)
            .onMuscleSelected { muscle, _ in
                HapticsManager.selection()
                selectedMuscle = muscle
            }
    }

    private func statusColor(_ status: BalanceStatus) -> Color {
        switch status {
        case .under: return .accentRed
        case .optimal: return .accentGreen
        case .over: return .accentPurple
        case .noData: return .textTertiary
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            if mode == .balance {
                legendDot(.accentRed, "Under")
                legendDot(.accentGreen, "Optimal")
                legendDot(.accentPurple, "Over")
            } else {
                legendDot(.textTertiary, "Low")
                legendDot(.accentOrange, "High")
            }
        }
        .padding(.horizontal, 20)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Antagonist ratios

    private var antagonistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety Checks")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            ForEach(report.antagonistPairs) { pair in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pair.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if let ratio = pair.ratio {
                            Text(String(format: "%.2f", ratio))
                                .font(.metric(14))
                                .foregroundStyle(pair.isBalanced ? Color.accentGreen : Color.accentYellow)
                        }
                    }
                    Text(pair.note)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .card()
        .padding(.horizontal, 16)
    }

    // MARK: - Focus strip

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus On")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            ForEach(report.recommendations) { rec in
                Button {
                    HapticsManager.selection()
                    selectedMuscle = rec.group
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.group.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                            Text(rec.reason)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
        .padding(.horizontal, 16)
    }
}
