import Foundation
@testable import HealthAggregator

/// Shared factories for building test fixtures concisely.
enum Fixture {

    // MARK: - Workouts

    /// A completed workout session containing one exercise with the given (weightKg, reps) sets.
    static func session(
        daysAgo: Int,
        exercise: String,
        sets: [(weightKg: Double?, reps: Int)],
        type: WorkoutType = .push,
        completed: Bool = true
    ) -> WorkoutSession {
        let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        var session = WorkoutSession(name: "Test", type: type, startDate: start)
        if completed { session.endDate = start.addingTimeInterval(3600) }
        var ex = WorkoutExercise(name: exercise, orderIndex: 0)
        ex.sets = sets.enumerated().map { i, s in
            WorkoutSet(setNumber: i + 1, weightKg: s.weightKg, reps: s.reps, isCompleted: completed)
        }
        session.exercises = [ex]
        return session
    }

    static func rule(
        _ strategy: ProgressionStrategy,
        equipment: Equipment = .barbell,
        minReps: Int = 5,
        maxReps: Int = 5,
        sets: Int = 3
    ) -> ProgressionRule {
        ProgressionRule(strategy: strategy, equipment: equipment, minReps: minReps, maxReps: maxReps, sets: sets)
    }

    // MARK: - Habits

    static func habit(
        _ name: String = "Test Habit",
        category: HabitCategory = .custom,
        slot: HabitTimeSlot = .anytime
    ) -> Habit {
        Habit(name: name, category: category, icon: category.icon, colorHex: category.colorHex, timeSlot: slot)
    }

    // MARK: - Metrics

    static func metrics(
        sex: UserMetrics.Sex = .male,
        age: Int? = 30,
        weightKg: Double = 0,
        heightM: Double = 0,
        bodyFatFraction: Double = 0,
        leanMassKg: Double = 0,
        vo2Max: Double = 0,
        hrv: Double = 0,
        hrvBaseline: Double = 0,
        recoveryScore: Double? = nil,
        sleepHours: Double = 0,
        steps: Double = 0,
        weeklyExerciseMinutes: Double = 0,
        trainingMonths: Int = 0
    ) -> UserMetrics {
        var m = UserMetrics()
        m.sex = sex
        m.age = age
        m.weightKg = weightKg
        m.heightM = heightM
        m.bodyFatFraction = bodyFatFraction
        m.leanMassKg = leanMassKg
        m.vo2Max = vo2Max
        m.hrv = hrv
        m.hrvBaseline = hrvBaseline
        m.recoveryScore = recoveryScore
        m.sleepHours = sleepHours
        m.steps = steps
        m.weeklyExerciseMinutes = weeklyExerciseMinutes
        m.trainingMonths = trainingMonths
        return m
    }
}

/// JSONDecoder configured exactly like WhoopService uses (ISO-8601 dates, no fractional seconds).
extension JSONDecoder {
    static var whoop: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
