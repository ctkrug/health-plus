import Foundation
import MuscleMap

// MARK: - Output types

enum BalanceStatus {
    case noData, under, optimal, over
}

struct MuscleGroupBalance: Identifiable {
    var id: Muscle { group }
    let group: Muscle
    let status: BalanceStatus
    let weeklySets: Double
    let mev: Double
    let mrv: Double
}

struct AntagonistPairStatus: Identifiable {
    var id: String { label }
    let label: String
    let ratio: Double?
    let targetRange: ClosedRange<Double>
    let isBalanced: Bool
    let note: String
    /// Every muscle that feeds this ratio (both sides) — lets callers match a specific muscle to
    /// its relevant pair without parsing `label` (some pairs, e.g. "Pull : Push", don't mention any
    /// single muscle's display name).
    let muscles: Set<Muscle>
}

struct MuscleRecommendation: Identifiable {
    var id: Muscle { group }
    let group: Muscle
    let reason: String
    let suggestedExercises: [ExerciseDefinition]
}

struct MuscleBalanceReport {
    /// nil when there isn't enough history yet to mean anything (see `MuscleBalanceEngine.minHistoryDays`).
    let overallScore: Int?
    let perMuscle: [MuscleGroupBalance]
    let antagonistPairs: [AntagonistPairStatus]
    let recommendations: [MuscleRecommendation]
    let hasEnoughData: Bool
}

/// **Pure** muscle-volume and balance-scoring engine — no UI, no persistence. Follows the
/// `InsightsEngine`/`ProgressionEngine` convention: every threshold below is cited in
/// `docs/SCIENCE.md §11`, which also flags them as field-consensus estimates pending a citation
/// verification pass (see docs/SPEC-lift-charts-and-muscle-map.md §2.5).
enum MuscleBalanceEngine {

    /// Below this much total training history, don't score anything — a fresh account shouldn't
    /// see a misleading "under-trained" flag on every muscle.
    static let minHistoryDays: TimeInterval = 14 * 86400

    // MARK: Volume landmarks (approximate weekly working sets, natural lifter)

    private struct Landmark { let mev: Double; let mrv: Double }

    /// Explicit order so the UI (recommendation strip, detail lists) is stable across renders.
    static let orderedMuscles: [Muscle] = [
        .chest, .upperBack, .lowerBack, .trapezius, .deltoids, .rotatorCuff,
        .biceps, .triceps, .quadriceps, .hamstring, .gluteal, .adductors,
        .calves, .abs, .obliques,
    ]

    private static let landmarks: [Muscle: Landmark] = [
        .chest:       Landmark(mev: 8, mrv: 20),
        .upperBack:   Landmark(mev: 10, mrv: 25),
        .lowerBack:   Landmark(mev: 2, mrv: 10),
        .trapezius:   Landmark(mev: 4, mrv: 16),
        .deltoids:    Landmark(mev: 6, mrv: 22),
        .rotatorCuff: Landmark(mev: 2, mrv: 10),
        .biceps:      Landmark(mev: 6, mrv: 20),
        .triceps:     Landmark(mev: 6, mrv: 18),
        .quadriceps:  Landmark(mev: 8, mrv: 20),
        .hamstring:   Landmark(mev: 6, mrv: 16),
        .gluteal:     Landmark(mev: 4, mrv: 16),
        .adductors:   Landmark(mev: 2, mrv: 10),
        .calves:      Landmark(mev: 8, mrv: 20),
        .abs:         Landmark(mev: 0, mrv: 20),
        .obliques:    Landmark(mev: 0, mrv: 16),
    ]

    /// Muscle groups whose training status also matters for Charlie's knee/back rehab — used to
    /// prioritize recommendations and to pick which antagonist ratios get a safety note.
    static let rehabRelevant: Set<Muscle> = [.hamstring, .lowerBack, .gluteal, .abs, .obliques, .quadriceps]

    // MARK: - Volume aggregation

    /// Fractional set-volume per muscle over the trailing `windowDays`. Primary mover gets full
    /// credit per completed set, secondary/synergist movers get half credit — the standard
    /// approach used by RP-style volume tracking (see docs/SCIENCE.md §11).
    static func weeklyVolume(sessions: [WorkoutSession], windowDays: Int = 7) -> [Muscle: Double] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? .distantPast
        var totals: [Muscle: Double] = [:]
        for session in sessions where session.startDate >= cutoff {
            for exercise in session.exercises {
                let setCount = Double(exercise.completedSets.count)
                guard setCount > 0, let def = ExerciseLibrary.find(exercise.name) else { continue }
                if let primary = def.primaryCanonicalMuscle {
                    totals[primary.balanceGroup, default: 0] += setCount
                }
                for secondary in def.secondaryCanonicalMuscles {
                    totals[secondary.balanceGroup, default: 0] += setCount * 0.5
                }
            }
        }
        return totals
    }

    /// Per-week set-volume for one muscle over the trailing `weeks` — same shape as
    /// `WorkoutStore.weeklyVolume(for:weeks:)`, for the muscle-detail trend chart.
    static func weeklyVolumeHistory(muscle: Muscle, sessions: [WorkoutSession], weeks: Int = 8) -> [(Date, Double)] {
        let calendar = Calendar.current
        return (0..<weeks).map { weekOffset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            var total = 0.0
            for session in sessions where session.startDate >= weekStart && session.startDate < weekEnd {
                for exercise in session.exercises {
                    let setCount = Double(exercise.completedSets.count)
                    guard setCount > 0, let def = ExerciseLibrary.find(exercise.name) else { continue }
                    if def.primaryCanonicalMuscle?.balanceGroup == muscle { total += setCount }
                    if def.secondaryCanonicalMuscles.contains(where: { $0.balanceGroup == muscle }) { total += setCount * 0.5 }
                }
            }
            return (weekStart, total)
        }.reversed()
    }

    // MARK: - Report

    static func balanceReport(sessions: [WorkoutSession]) -> MuscleBalanceReport {
        let hasEnoughData = sessions.map(\.startDate).min()
            .map { Date().timeIntervalSince($0) >= minHistoryDays } ?? false
        let volumes = weeklyVolume(sessions: sessions, windowDays: 7)

        let perMuscle: [MuscleGroupBalance] = orderedMuscles.map { muscle in
            let landmark = landmarks[muscle] ?? Landmark(mev: 0, mrv: 0)
            let sets = volumes[muscle] ?? 0
            let status: BalanceStatus
            if !hasEnoughData || sets == 0 {
                status = .noData
            } else if sets < landmark.mev {
                status = .under
            } else if sets > landmark.mrv {
                status = .over
            } else {
                status = .optimal
            }
            return MuscleGroupBalance(group: muscle, status: status, weeklySets: sets,
                                       mev: landmark.mev, mrv: landmark.mrv)
        }

        let antagonistPairs = computeAntagonistPairs(volumes: volumes, hasEnoughData: hasEnoughData)
        let recommendations = computeRecommendations(perMuscle: perMuscle)
        let overallScore = hasEnoughData ? computeScore(perMuscle: perMuscle, antagonistPairs: antagonistPairs) : nil

        return MuscleBalanceReport(overallScore: overallScore, perMuscle: perMuscle,
                                    antagonistPairs: antagonistPairs, recommendations: recommendations,
                                    hasEnoughData: hasEnoughData)
    }

    // MARK: - Antagonist ratios (docs/SCIENCE.md §11)

    private static func ratio(_ numerator: [Muscle], _ denominator: [Muscle], volumes: [Muscle: Double]) -> Double? {
        let num = numerator.reduce(0.0) { $0 + (volumes[$1] ?? 0) }
        let den = denominator.reduce(0.0) { $0 + (volumes[$1] ?? 0) }
        guard den > 0, num > 0 else { return nil }
        return num / den
    }

    private static func computeAntagonistPairs(volumes: [Muscle: Double], hasEnoughData: Bool) -> [AntagonistPairStatus] {
        guard hasEnoughData else { return [] }
        var pairs: [AntagonistPairStatus] = []

        let hqMuscles: [Muscle] = [.hamstring, .quadriceps]
        if let hq = ratio([.hamstring], [.quadriceps], volumes: volumes) {
            let target = 0.6...0.8
            pairs.append(AntagonistPairStatus(
                label: "Hamstrings : Quads", ratio: hq, targetRange: target, isBalanced: target.contains(hq),
                note: "Quad-dominant training is a known knee-strain risk factor — relevant to your knee rehab.",
                muscles: Set(hqMuscles)))
        }
        let pullPushMuscles: [Muscle] = [.upperBack, .trapezius, .biceps, .chest, .triceps, .deltoids]
        if let pullPush = ratio([.upperBack, .trapezius, .biceps], [.chest, .triceps, .deltoids], volumes: volumes) {
            let target = 1.0...1.5
            pairs.append(AntagonistPairStatus(
                label: "Pull : Push", ratio: pullPush, targetRange: target, isBalanced: target.contains(pullPush),
                note: "Push-dominant training is linked to rounded-shoulder posture and shoulder-impingement risk.",
                muscles: Set(pullPushMuscles)))
        }
        let coreMuscles: [Muscle] = [.lowerBack, .gluteal, .hamstring, .abs, .obliques]
        if let core = ratio([.lowerBack, .gluteal, .hamstring], [.abs, .obliques], volumes: volumes) {
            let target = 0.8...1.5
            pairs.append(AntagonistPairStatus(
                label: "Posterior Chain : Anterior Core", ratio: core, targetRange: target, isBalanced: target.contains(core),
                note: "Balanced core training is associated with lower low-back-pain risk — relevant to your back rehab.",
                muscles: Set(coreMuscles)))
        }
        return pairs
    }

    // MARK: - Recommendations

    private static func computeRecommendations(perMuscle: [MuscleGroupBalance]) -> [MuscleRecommendation] {
        let ranked = perMuscle.filter { $0.status == .under }.sorted { a, b in
            let aSafety = rehabRelevant.contains(a.group), bSafety = rehabRelevant.contains(b.group)
            if aSafety != bSafety { return aSafety && !bSafety }
            let aDeficit = a.mev > 0 ? (a.mev - a.weeklySets) / a.mev : 0
            let bDeficit = b.mev > 0 ? (b.mev - b.weeklySets) / b.mev : 0
            return aDeficit > bDeficit
        }
        return ranked.prefix(3).map { balance in
            let reason = rehabRelevant.contains(balance.group)
                ? "Below target volume this week — also relevant to your knee/back rehab work."
                : "Below target volume this week."
            let exercises = ExerciseLibrary.all
                .filter { $0.primaryCanonicalMuscle?.balanceGroup == balance.group }
                .prefix(3)
            return MuscleRecommendation(group: balance.group, reason: reason, suggestedExercises: Array(exercises))
        }
    }

    // MARK: - Composite score

    private static func computeScore(perMuscle: [MuscleGroupBalance], antagonistPairs: [AntagonistPairStatus]) -> Int {
        let scored = perMuscle.filter { $0.status != .noData }
        guard !scored.isEmpty else { return 50 }
        let coverage = Double(scored.filter { $0.status == .optimal || $0.status == .over }.count) / Double(scored.count)
        let ratioAdherence = antagonistPairs.isEmpty
            ? 1.0
            : Double(antagonistPairs.filter(\.isBalanced).count) / Double(antagonistPairs.count)
        let overPenalty = Double(scored.filter { $0.status == .over }.count) * 0.05
        let raw = (coverage * 0.6 + ratioAdherence * 0.4) - overPenalty
        return Int((max(0, min(1, raw)) * 100).rounded())
    }

    // MARK: - Notification trigger (see NotificationService.sendMuscleImbalanceAlert)

    /// The single worst-priority recommendation to alert on, or nil if nothing qualifies.
    /// Rate-limiting (at most one alert per recompute) is the caller's job — this just picks who.
    static func topAlertCandidate(from report: MuscleBalanceReport) -> MuscleRecommendation? {
        report.recommendations.first
    }
}
