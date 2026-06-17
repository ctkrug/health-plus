import Foundation

/// The brain of the app. Analyzes workout history and tells you exactly what to do next.
final class ProgressionEngine {

    // MARK: - Core suggestion

    static func suggestion(
        for exerciseName: String,
        rule: ProgressionRule,
        history: [WorkoutSession]
    ) -> ProgressionSuggestion {

        // Pull sessions where this exercise was logged, ordered newest first
        let relevant = history
            .filter { $0.exercises.contains { $0.name == exerciseName } }
            .sorted { $0.startDate > $1.startDate }

        guard !relevant.isEmpty else {
            return .firstTime(rule: rule)
        }

        let lastSession = relevant[0]
        guard let lastExercise = lastSession.exercises.first(where: { $0.name == exerciseName }) else {
            return .firstTime(rule: rule)
        }

        let completedSets = lastExercise.completedSets
        guard !completedSets.isEmpty else { return .firstTime(rule: rule) }

        let lastWeightKg = completedSets.compactMap(\.weightKg).last ?? 0
        let lastReps = completedSets.compactMap(\.reps)
        let avgReps = lastReps.isEmpty ? 0 : lastReps.reduce(0, +) / lastReps.count
        let allSetsCompleted = completedSets.count >= rule.sets

        // How many sessions since we last increased weight
        let sessionsSinceIncrease = sessionsSinceWeightIncrease(
            exerciseName: exerciseName, history: relevant, currentWeight: lastWeightKg
        )

        switch rule.strategy {
        case .doubleProgression:
            return doubleProgressionSuggestion(
                rule: rule, lastWeightKg: lastWeightKg, lastReps: lastReps,
                allSetsCompleted: allSetsCompleted, sessionsSinceIncrease: sessionsSinceIncrease
            )

        case .linearWeight:
            return linearWeightSuggestion(
                rule: rule, lastWeightKg: lastWeightKg, avgReps: avgReps,
                allSetsCompleted: allSetsCompleted, sessionsSinceIncrease: sessionsSinceIncrease
            )

        case .repRange:
            return repRangeSuggestion(
                rule: rule, lastWeightKg: lastWeightKg, lastReps: lastReps,
                sessionsSinceIncrease: sessionsSinceIncrease
            )

        case .rpe, .none:
            return ProgressionSuggestion(
                action: .holdSteady,
                suggestedWeightKg: lastWeightKg,
                suggestedReps: avgReps > 0 ? avgReps : rule.minReps,
                message: "Match last session",
                isReadyToProgress: false,
                sessionsSinceLastIncrease: sessionsSinceIncrease,
                previousWeightKg: lastWeightKg,
                previousReps: avgReps
            )
        }
    }

    // MARK: - Strategy implementations

    private static func doubleProgressionSuggestion(
        rule: ProgressionRule, lastWeightKg: Double, lastReps: [Int],
        allSetsCompleted: Bool, sessionsSinceIncrease: Int
    ) -> ProgressionSuggestion {
        let minReps = rule.minReps
        let maxReps = rule.maxReps
        let minSetsHitTarget = lastReps.filter { $0 >= minReps }.count
        let allHitMax = lastReps.allSatisfy { $0 >= maxReps }

        if allSetsCompleted && allHitMax && lastWeightKg > 0 {
            // Every set hit max reps → increase weight, drop to min reps
            let newWeight = lastWeightKg + rule.effectiveProgressionKg
            return ProgressionSuggestion(
                action: .increaseWeight(by: rule.effectiveProgressionKg),
                suggestedWeightKg: newWeight,
                suggestedReps: minReps,
                message: coachMessage(lastWeightKg: lastWeightKg, newWeightKg: newWeight),
                isReadyToProgress: true,
                sessionsSinceLastIncrease: sessionsSinceIncrease,
                previousWeightKg: lastWeightKg,
                previousReps: lastReps.first
            )
        } else if allSetsCompleted && minSetsHitTarget == lastReps.count {
            // All sets hit min but not max → add a rep
            let currentAvg = lastReps.reduce(0, +) / max(lastReps.count, 1)
            let newReps = min(currentAvg + 1, maxReps)
            return ProgressionSuggestion(
                action: .increaseReps(by: 1),
                suggestedWeightKg: lastWeightKg,
                suggestedReps: newReps,
                message: "Add 1 rep — you're building to \(maxReps)×\(rule.sets)",
                isReadyToProgress: true,
                sessionsSinceLastIncrease: sessionsSinceIncrease,
                previousWeightKg: lastWeightKg,
                previousReps: currentAvg
            )
        } else {
            // Didn't hit all sets → hold and hit target
            let currentAvg = lastReps.isEmpty ? minReps : lastReps.reduce(0, +) / lastReps.count
            return ProgressionSuggestion(
                action: .holdSteady,
                suggestedWeightKg: lastWeightKg > 0 ? lastWeightKg : nil,
                suggestedReps: minReps,
                message: "Hit \(minReps) reps on all \(rule.sets) sets to progress",
                isReadyToProgress: false,
                sessionsSinceLastIncrease: sessionsSinceIncrease,
                previousWeightKg: lastWeightKg,
                previousReps: currentAvg
            )
        }
    }

    private static func linearWeightSuggestion(
        rule: ProgressionRule, lastWeightKg: Double, avgReps: Int,
        allSetsCompleted: Bool, sessionsSinceIncrease: Int
    ) -> ProgressionSuggestion {
        if allSetsCompleted && lastWeightKg > 0 {
            let newWeight = lastWeightKg + rule.effectiveProgressionKg
            return ProgressionSuggestion(
                action: .increaseWeight(by: rule.effectiveProgressionKg),
                suggestedWeightKg: newWeight,
                suggestedReps: rule.minReps,
                message: coachMessage(lastWeightKg: lastWeightKg, newWeightKg: newWeight),
                isReadyToProgress: true,
                sessionsSinceLastIncrease: sessionsSinceIncrease,
                previousWeightKg: lastWeightKg,
                previousReps: avgReps
            )
        }
        return ProgressionSuggestion(
            action: .holdSteady,
            suggestedWeightKg: lastWeightKg > 0 ? lastWeightKg : nil,
            suggestedReps: rule.minReps,
            message: "Complete all sets to advance weight next session",
            isReadyToProgress: false,
            sessionsSinceLastIncrease: sessionsSinceIncrease,
            previousWeightKg: lastWeightKg,
            previousReps: avgReps
        )
    }

    private static func repRangeSuggestion(
        rule: ProgressionRule, lastWeightKg: Double, lastReps: [Int],
        sessionsSinceIncrease: Int
    ) -> ProgressionSuggestion {
        let allAboveMax = lastReps.allSatisfy { $0 >= rule.maxReps }
        let avgReps = lastReps.isEmpty ? rule.minReps : lastReps.reduce(0, +) / lastReps.count

        if allAboveMax && lastWeightKg > 0 {
            let newWeight = lastWeightKg + rule.effectiveProgressionKg
            return ProgressionSuggestion(
                action: .increaseWeight(by: rule.effectiveProgressionKg),
                suggestedWeightKg: newWeight,
                suggestedReps: rule.minReps,
                message: "You're above \(rule.maxReps) reps — add weight, start at \(rule.minReps)",
                isReadyToProgress: true,
                sessionsSinceLastIncrease: sessionsSinceIncrease,
                previousWeightKg: lastWeightKg,
                previousReps: avgReps
            )
        }
        return ProgressionSuggestion(
            action: .holdSteady,
            suggestedWeightKg: lastWeightKg > 0 ? lastWeightKg : nil,
            suggestedReps: avgReps,
            message: "Work up to \(rule.maxReps) reps on all sets",
            isReadyToProgress: false,
            sessionsSinceLastIncrease: sessionsSinceIncrease,
            previousWeightKg: lastWeightKg,
            previousReps: avgReps
        )
    }

    // MARK: - Per-set suggestion (used to pre-populate each set row)

    static func suggestedSet(
        setNumber: Int,
        suggestion: ProgressionSuggestion,
        rule: ProgressionRule
    ) -> WorkoutSet {
        WorkoutSet(
            setNumber: setNumber,
            weightKg: suggestion.suggestedWeightKg,
            weightUnit: .lbs,
            reps: suggestion.suggestedReps,
            targetReps: suggestion.suggestedReps,
            targetWeightKg: suggestion.suggestedWeightKg
        )
    }

    // MARK: - Session population

    /// Returns a WorkoutSession with all sets pre-populated from history
    static func populateSession(
        programWorkout: ProgramWorkout,
        history: [WorkoutSession]
    ) -> WorkoutSession {
        var session = programWorkout.toWorkoutSession()
        for i in session.exercises.indices {
            let name = session.exercises[i].name
            guard let pe = programWorkout.exercises.first(where: { $0.exerciseName == name }) else { continue }
            let sugg = suggestion(for: name, rule: pe.rule, history: history)
            session.exercises[i].sets = (0..<pe.rule.sets).map { j in
                suggestedSet(setNumber: j + 1, suggestion: sugg, rule: pe.rule)
            }
        }
        return session
    }

    // MARK: - Progress summary (for coach messages)

    static func weeklyCoachSummary(sessions: [WorkoutSession], program: TrainingProgram?) -> [String] {
        var messages: [String] = []
        // Use dateInterval to get exact week boundaries — avoids cross-year week-number collision
        let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), duration: 0)
        let thisWeek = sessions.filter { weekInterval.contains($0.startDate) }
        if thisWeek.isEmpty {
            messages.append("No sessions yet this week. Let's get one in!")
        } else {
            messages.append("Great work — \(thisWeek.count) session\(thisWeek.count == 1 ? "" : "s") this week.")
        }
        return messages
    }

    // MARK: - Helpers

    private static func sessionsSinceWeightIncrease(
        exerciseName: String, history: [WorkoutSession], currentWeight: Double
    ) -> Int {
        var count = 0
        for session in history {
            guard let ex = session.exercises.first(where: { $0.name == exerciseName }) else { continue }
            let w = ex.completedSets.compactMap(\.weightKg).max() ?? 0
            if w < currentWeight { break }
            count += 1
        }
        return count
    }

    private static func coachMessage(lastWeightKg: Double, newWeightKg: Double) -> String {
        let lastLbs = String(format: "%.1f", lastWeightKg / 0.453592)
        let newLbs = String(format: "%.1f", newWeightKg / 0.453592)
        let messages = [
            "Time to level up — add weight! \(lastLbs) → \(newLbs) lb",
            "You earned it — bump to \(newLbs) lb",
            "Progressive overload achieved — \(newLbs) lb today",
            "Last session was clean — \(newLbs) lb is your new target",
        ]
        return messages[Int.random(in: 0..<messages.count)]
    }
}

// MARK: - Swim progression

extension ProgressionEngine {
    static func swimSuggestion(exerciseName: String, history: [WorkoutSession]) -> SwimProgressionSuggestion {
        let relevant = history
            .filter { $0.type.isSwim && $0.exercises.contains { $0.name == exerciseName } }
            .sorted { $0.startDate > $1.startDate }

        guard let last = relevant.first,
              let lastEx = last.exercises.first(where: { $0.name == exerciseName }) else {
            return SwimProgressionSuggestion(
                message: "First time — establish your baseline pace",
                suggestedDistance: 100, suggestedSets: 4,
                previousBestPace: nil, targetPace: nil, isReadyToProgress: false
            )
        }

        let completedSets = lastEx.completedSets
        let totalDistLast = completedSets.compactMap(\.distanceMeters).reduce(0, +)
        let avgTime = completedSets.compactMap(\.durationSeconds).reduce(0.0, +) / Double(max(completedSets.count, 1))
        let pacePer100 = totalDistLast > 0 ? avgTime / totalDistLast * 100 : nil

        return SwimProgressionSuggestion(
            message: totalDistLast > 0 ? "Aim to beat last session's pace or add a set" : "Complete all sets at target pace",
            suggestedDistance: completedSets.first?.distanceMeters ?? 100,
            suggestedSets: completedSets.count,
            previousBestPace: pacePer100,
            targetPace: pacePer100.map { $0 * 0.98 },  // 2% faster target
            isReadyToProgress: completedSets.count >= 4
        )
    }
}

struct SwimProgressionSuggestion {
    let message: String
    let suggestedDistance: Double
    let suggestedSets: Int
    let previousBestPace: Double?   // seconds per 100m
    let targetPace: Double?
    let isReadyToProgress: Bool

    var previousBestPaceString: String {
        guard let p = previousBestPace else { return "—" }
        return String(format: "%d:%02d /100m", Int(p) / 60, Int(p) % 60)
    }
}
