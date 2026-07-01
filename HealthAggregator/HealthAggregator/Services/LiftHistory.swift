import Foundation

/// One session's worth of performance for a single exercise — the unit of "progress" a lift chart
/// plots. One point per session (not per set) so the chart reads as a trend, not set-level noise.
struct LiftDataPoint: Identifiable {
    var id: UUID { sessionID }
    let date: Date
    let sessionID: UUID
    let topWeightKg: Double      // heaviest completed set that session
    let topReps: Int             // reps at that top set
    let estimated1RM: Double     // Epley, from the best set that session (may differ from topWeightKg's set)
    let totalVolume: Double      // Σ weight × reps for this exercise that session
    let isPR: Bool
}

/// Pure aggregation from workout history to a per-lift time series. No UI, no persistence —
/// mirrors the `ProgressionEngine`/`InsightsEngine` convention.
enum LiftHistory {
    /// All data points for `exerciseName`, oldest first, matched case-insensitively/trimmed so
    /// minor naming variance in logged sessions doesn't silently drop history.
    static func points(for exerciseName: String, in sessions: [WorkoutSession]) -> [LiftDataPoint] {
        let target = normalize(exerciseName)
        let matches = sessions.compactMap { session -> LiftDataPoint? in
            let exercises = session.exercises.filter { normalize($0.name) == target }
            let completedSets = exercises.flatMap(\.completedSets)
            guard !completedSets.isEmpty else { return nil }

            let bestSet = exercises.compactMap(\.bestSet).max { a, b in
                (a.estimated1RM ?? 0) < (b.estimated1RM ?? 0)
            }
            let topWeightSet = completedSets.max { a, b in (a.weightKg ?? 0) < (b.weightKg ?? 0) }
            let volume = exercises.reduce(0) { $0 + $1.totalVolume }
            let isPR = completedSets.contains { $0.isPR }

            return LiftDataPoint(
                date: session.startDate,
                sessionID: session.id,
                topWeightKg: topWeightSet?.weightKg ?? 0,
                topReps: topWeightSet?.reps ?? 0,
                estimated1RM: bestSet?.estimated1RM ?? 0,
                totalVolume: volume,
                isPR: isPR
            )
        }
        return matches.sorted { $0.date < $1.date }
    }

    /// Every exercise name with at least one completed set, for the lift picker.
    static func trainedExerciseNames(in sessions: [WorkoutSession]) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for session in sessions.sorted(by: { $0.startDate < $1.startDate }) {
            for exercise in session.exercises where !exercise.completedSets.isEmpty {
                let key = normalize(exercise.name)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                names.append(exercise.name)
            }
        }
        return names.sorted()
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
