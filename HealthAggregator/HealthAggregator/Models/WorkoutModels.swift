import Foundation
import SwiftUI

// MARK: - Enums

enum WorkoutType: String, CaseIterable, Codable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case fullBody = "Full Body"
    case upper = "Upper"
    case lower = "Lower"
    case poolSwim = "Pool Swim"
    case openWater = "Open Water"
    case cardio = "Cardio"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .push, .pull, .upper, .lower, .fullBody: return "dumbbell.fill"
        case .legs: return "figure.walk"
        case .poolSwim: return "figure.pool.swim"
        case .openWater: return "water.waves"
        case .cardio: return "heart.fill"
        case .custom: return "plus.circle.fill"
        }
    }

    var isSwim: Bool { self == .poolSwim || self == .openWater }
}

enum StrokeType: String, CaseIterable, Codable {
    case freestyle = "Freestyle"
    case backstroke = "Backstroke"
    case breaststroke = "Breaststroke"
    case butterfly = "Butterfly"
    case medley = "Medley"
    case kickboard = "Kickboard"
    case pull = "Pull Buoy"
    case drill = "Drill"
}

enum WeightUnit: String, CaseIterable, Codable {
    case lbs = "lb"
    case kg = "kg"

    var multiplierToKg: Double { self == .kg ? 1.0 : 0.453592 }
}

enum DistanceUnit: String, CaseIterable, Codable {
    case meters = "m"
    case yards = "yd"
    case km = "km"
    case miles = "mi"
}

// MARK: - Models

struct WorkoutSession: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: WorkoutType
    var startDate: Date
    var endDate: Date?
    var exercises: [WorkoutExercise] = []
    var notes: String = ""
    var totalVolumeKg: Double = 0
    var totalDistanceMeters: Double? = nil

    var duration: TimeInterval { (endDate ?? Date()).timeIntervalSince(startDate) }
    var isComplete: Bool { endDate != nil }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count } }
    var progressFraction: Double {
        let t = totalSets
        return t == 0 ? 0 : Double(completedSets) / Double(t)
    }
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var orderIndex: Int
    var sets: [WorkoutSet] = []
    var notes: String = ""
    var isSuperset: Bool = false
    var supersetGroupID: UUID? = nil
    var progressionRule: ProgressionRule? = nil   // set for template-started workouts so the progression engine fires

    var completedSets: [WorkoutSet] { sets.filter(\.isCompleted) }
    var totalVolume: Double {
        completedSets.compactMap { s in
            guard let w = s.weightKg, let r = s.reps else { return nil }
            return w * Double(r)
        }.reduce(0, +)
    }

    var bestSet: WorkoutSet? {
        completedSets.max { a, b in
            let aE = a.estimated1RM ?? 0
            let bE = b.estimated1RM ?? 0
            return aE < bE
        }
    }
}

struct WorkoutSet: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var setNumber: Int
    var weightKg: Double?
    var weightUnit: WeightUnit = .lbs
    var reps: Int?
    var distanceMeters: Double?
    var durationSeconds: Double?
    var strokeType: StrokeType?
    var swolfScore: Int?
    var isCompleted: Bool = false
    var isPR: Bool = false
    var completedAt: Date?
    var targetReps: Int?
    var targetWeightKg: Double?

    var weightDisplayLbs: Double? {
        guard let w = weightKg else { return nil }
        return w / 0.453592
    }

    var estimated1RM: Double? {
        guard let w = weightKg, let r = reps, r > 0, r <= 36 else { return nil }
        return w * (1 + Double(r) / 30.0)  // Epley formula
    }

    var displayWeight: String {
        guard let w = weightKg else { return "—" }
        switch weightUnit {
        case .lbs: return String(format: "%.1f", w / 0.453592)
        case .kg: return String(format: "%.1f", w)
        }
    }
}

// MARK: - Templates

struct WorkoutTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: WorkoutType
    var exercises: [TemplateExercise] = []
    var createdAt: Date = Date()
    var lastUsed: Date? = nil
    var useCount: Int = 0

    func toSession() -> WorkoutSession {
        var session = WorkoutSession(name: name, type: type, startDate: Date())
        session.exercises = exercises.enumerated().map { i, te in
            var ex = WorkoutExercise(name: te.name, orderIndex: i)
            ex.isSuperset = te.supersetGroupID != nil
            ex.supersetGroupID = te.supersetGroupID
            ex.progressionRule = te.derivedProgressionRule
            ex.sets = (0..<te.defaultSets).map { j in
                WorkoutSet(
                    setNumber: j + 1,
                    weightKg: te.defaultWeightKg,
                    weightUnit: te.defaultWeightUnit,
                    reps: te.defaultReps,
                    targetReps: te.maxReps ?? te.defaultReps,
                    targetWeightKg: te.defaultWeightKg
                )
            }
            return ex
        }
        return session
    }
}

struct TemplateExercise: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var orderIndex: Int
    var defaultSets: Int = 3
    var defaultReps: Int? = 8
    var maxReps: Int? = nil              // upper end of rep range (e.g. 12 in "8–12"); nil = exact reps
    var defaultWeightKg: Double? = nil
    var defaultWeightUnit: WeightUnit = .lbs
    var restSeconds: Int = 90
    var strokeType: StrokeType? = nil
    var defaultDistanceMeters: Double? = nil
    var muscleGroups: [String] = []
    var supersetGroupID: UUID? = nil     // exercises sharing an ID are performed as a superset

    /// Derive a repRange ProgressionRule from this template's sets/reps.
    /// Equipment is inferred from the exercise name (machine → .machine, barbell cues → .barbell,
    /// else .dumbbell). This lets template-started workouts drive the same progression engine
    /// that program workouts use.
    var derivedProgressionRule: ProgressionRule {
        let n = name.lowercased()
        let eq: Equipment
        if n.contains("machine") || n.contains("lat pull") || n.contains("leg press")
            || n.contains("leg extension") || n.contains("leg curl") || n.contains("chest press machine")
            || n.contains("rowing machine") || n.contains("shoulder press machine") {
            eq = .machine
        } else if n.contains("barbell") || n.contains("deadlift") || n.contains("bench press") && !n.contains("dumbbell") {
            eq = .barbell
        } else {
            eq = .dumbbell
        }
        return ProgressionRule(
            strategy: .repRange,
            equipment: eq,
            minReps: defaultReps ?? 8,
            maxReps: maxReps ?? max((defaultReps ?? 8) + 4, 12),
            sets: defaultSets
        )
    }
}

// MARK: - PR Record

struct PersonalRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var estimated1RM: Double
    var date: Date
    var sessionID: UUID
}

// MARK: - Streak

struct WorkoutStreak {
    var currentDays: Int
    var longestDays: Int
    var lastWorkoutDate: Date?
}
