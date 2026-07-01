import SwiftUI
import MuscleMap

/// Tap-through detail for one muscle group: status, educational content, its weekly-volume trend,
/// any antagonist-ratio safety note, and exercises that target it.
struct MuscleGroupDetailView: View {
    @Environment(\.dismiss) var dismiss
    let muscle: Muscle
    let sessions: [WorkoutSession]

    private var report: MuscleBalanceReport { MuscleBalanceEngine.balanceReport(sessions: sessions) }
    private var balance: MuscleGroupBalance? { report.perMuscle.first { $0.group == muscle } }
    private var info: MuscleInfo { MuscleLibrary.info(for: muscle) }
    private var history: [(Date, Double)] { MuscleBalanceEngine.weeklyVolumeHistory(muscle: muscle, sessions: sessions) }
    private var relatedPair: AntagonistPairStatus? {
        report.antagonistPairs.first { $0.muscles.contains(muscle.balanceGroup) }
    }

    private var exercises: [ExerciseDefinition] {
        ExerciseLibrary.all.filter { $0.primaryCanonicalMuscle?.balanceGroup == muscle }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let s = balance, s.status != .noData {
                    volumeCard(s)
                }
                infoCard
                if let pair = relatedPair {
                    safetyCard(pair)
                }
                if !exercises.isEmpty {
                    exerciseCard
                }
                Spacer().frame(height: 30)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(info.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                if let anatomical = info.anatomicalName {
                    Text(anatomical)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            if let s = balance {
                statusChip(s.status)
            }
        }
    }

    private func statusChip(_ status: BalanceStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .under: return ("Under", .accentRed)
            case .optimal: return ("Optimal", .accentGreen)
            case .over: return ("Over", .accentPurple)
            case .noData: return ("No Data", .textTertiary)
            }
        }()
        return Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func volumeCard(_ s: MuscleGroupBalance) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weekly Volume")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(Int(s.weeklySets.rounded())) sets · target \(Int(s.mev))–\(Int(s.mrv))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            InteractiveTrendChart(
                points: history,
                color: .accentBlue,
                unit: "sets",
                valueFormat: { String(format: "%.0f", $0) },
                showAverage: false,
                yDomainPadding: 1,
                height: 140
            )
        }
        .card()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !info.function.isEmpty {
                infoRow(title: "Function", text: info.function)
            }
            if !info.whyItMatters.isEmpty {
                infoRow(title: "Why It Matters", text: info.whyItMatters)
            }
            if !info.synergists.isEmpty {
                infoRow(title: "Works With", text: info.synergists.map { MuscleLibrary.info(for: $0).displayName }.joined(separator: ", "))
            }
            if let antagonist = info.antagonist {
                infoRow(title: "Opposing Muscle", text: MuscleLibrary.info(for: antagonist).displayName)
            }
            if let notes = info.notes {
                infoRow(title: "Note", text: notes)
            }
        }
        .card()
    }

    private func infoRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.textTertiary)
                .tracking(1)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func safetyCard(_ pair: AntagonistPairStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .card()
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Exercises")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            ForEach(exercises) { ex in
                HStack {
                    Text(ex.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if let eq = ex.primaryEquipment.first {
                        Text(eq.rawValue)
                            .font(.metricLabel(11))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                if ex.id != exercises.last?.id {
                    Divider().overlay(Color.separatorColor)
                }
            }
        }
        .card()
    }
}
