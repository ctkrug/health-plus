import Foundation

// MARK: - Equipment

enum Equipment: String, CaseIterable, Codable {
    case barbell    = "Barbell"
    case dumbbell   = "Dumbbell"
    case machine    = "Machine"
    case cable      = "Cable"
    case bodyweight = "Bodyweight"
    case kettlebell = "Kettlebell"
    case band       = "Band"
    case ezBar      = "EZ Bar"
    case trapBar    = "Trap Bar"
    case smithMachine = "Smith Machine"

    var icon: String {
        switch self {
        case .barbell, .trapBar, .smithMachine: return "barbell"
        case .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.2.fill"
        case .cable: return "cable.coaxial"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .kettlebell: return "figure.strengthtraining.functional"
        case .band: return "arrow.left.and.right"
        case .ezBar: return "barbell"
        }
    }

    /// Smallest sensible weight jump for this equipment (in kg)
    var defaultProgressionKg: Double {
        switch self {
        case .barbell, .trapBar, .smithMachine: return 2.268  // 2.5 lb
        case .dumbbell: return 2.268                           // next dumbbell pair
        case .machine: return 4.536                            // 10 lb plate
        case .cable: return 2.268                              // 2.5 lb stack jump
        case .ezBar: return 2.268
        case .bodyweight, .band, .kettlebell: return 0
        }
    }
}

// MARK: - Progression Rule

enum ProgressionStrategy: String, Codable, CaseIterable {
    case doubleProgression = "Double Progression"   // reps then weight
    case linearWeight      = "Linear Weight"         // add weight every session
    case repRange          = "Rep Range"             // hit top of range → increase weight
    case rpe               = "RPE Based"
    case none              = "None"

    var description: String {
        switch self {
        case .doubleProgression: return "Hit all reps → add weight next session"
        case .linearWeight: return "Add weight every session"
        case .repRange: return "Hit top of rep range → increase weight"
        case .rpe: return "Based on feel"
        case .none: return "Manual"
        }
    }
}

struct ProgressionRule: Codable, Equatable {
    var strategy: ProgressionStrategy = .doubleProgression
    var equipment: Equipment = .barbell
    var minReps: Int = 5
    var maxReps: Int = 5
    var sets: Int = 5
    var progressionKg: Double?       // override default increment

    var effectiveProgressionKg: Double {
        progressionKg ?? equipment.defaultProgressionKg
    }

    /// The target reps for a given set number (all same for now, can add pyramid later)
    func targetReps(forSet _: Int) -> Int { minReps }
}

// MARK: - Progression Suggestion

struct ProgressionSuggestion {
    enum Action {
        case increaseWeight(by: Double)
        case increaseReps(by: Int)
        case holdSteady
        case deload
        case firstTime
    }

    let action: Action
    let suggestedWeightKg: Double?
    let suggestedReps: Int
    let message: String
    let isReadyToProgress: Bool
    let sessionsSinceLastIncrease: Int
    let previousWeightKg: Double?
    let previousReps: Int?

    static func firstTime(rule: ProgressionRule) -> ProgressionSuggestion {
        .init(action: .firstTime, suggestedWeightKg: nil, suggestedReps: rule.minReps,
              message: "First time — start light and focus on form", isReadyToProgress: false,
              sessionsSinceLastIncrease: 0, previousWeightKg: nil, previousReps: nil)
    }
}

// MARK: - Training Program

struct TrainingProgram: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var workouts: [ProgramWorkout] = []    // A, B, C, D…
    var currentWorkoutIndex: Int = 0
    var createdAt: Date = Date()
    var isActive: Bool = false
    var daysPerWeek: Int = 3
    var goal: ProgramGoal = .strength
    var lastCompletedAt: Date? = nil

    var nextWorkout: ProgramWorkout? {
        guard !workouts.isEmpty else { return nil }
        return workouts[currentWorkoutIndex % workouts.count]
    }

    var nextWorkoutLabel: String {
        guard !workouts.isEmpty else { return "No workouts" }
        let w = workouts[currentWorkoutIndex % workouts.count]
        return "Workout \(w.label) — \(w.name)"
    }

    mutating func advance() {
        currentWorkoutIndex = (currentWorkoutIndex + 1) % max(workouts.count, 1)
        lastCompletedAt = Date()
    }
}

struct ProgramWorkout: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var label: String          // "A", "B", "C" or "1", "2", "3"
    var type: WorkoutType
    var exercises: [ProgramExercise] = []
    var notes: String = ""

    func toWorkoutSession() -> WorkoutSession {
        var session = WorkoutSession(name: "\(label) — \(name)", type: type, startDate: Date())
        session.exercises = exercises.enumerated().map { i, pe in
            var ex = WorkoutExercise(name: pe.exerciseName, orderIndex: i)
            ex.sets = (0..<pe.rule.sets).map { j in
                WorkoutSet(
                    setNumber: j + 1,
                    reps: pe.rule.minReps,
                    targetReps: pe.rule.minReps
                )
            }
            return ex
        }
        return session
    }
}

struct ProgramExercise: Identifiable, Codable {
    var id: UUID = UUID()
    var exerciseName: String
    var equipment: Equipment
    var orderIndex: Int
    var rule: ProgressionRule
    var notes: String = ""
    var muscleGroups: [String] = []

    // Swim-specific
    var isSwim: Bool = false
    var swimDistance: Double? = nil     // meters per set
    var swimStroke: StrokeType? = nil
    var targetPacePer100: Double? = nil  // seconds
}

enum ProgramGoal: String, CaseIterable, Codable {
    case strength      = "Strength"
    case hypertrophy   = "Hypertrophy"
    case powerlifting  = "Powerlifting"
    case endurance     = "Endurance"
    case fat_loss      = "Fat Loss"
    case swim          = "Swim"
    case general       = "General Fitness"
}

// MARK: - Swim Set

struct SwimSet: Identifiable, Codable {
    var id: UUID = UUID()
    var distance: Double       // meters
    var stroke: StrokeType
    var targetTime: Double?    // seconds
    var actualTime: Double?    // seconds
    var interval: Double?      // total rest+swim interval (seconds)
    var isCompleted: Bool = false
    var notes: String = ""

    var swolfScore: Int? {
        guard let t = actualTime, distance > 0 else { return nil }
        let strokes = Int(t / 1.5)   // rough estimate
        let seconds = Int(t)
        return seconds + strokes
    }

    var pacePer100: Double? {
        guard let t = actualTime, distance > 0 else { return nil }
        return t / distance * 100
    }

    var paceString: String {
        guard let p = pacePer100 else { return "—" }
        let min = Int(p) / 60
        let sec = Int(p) % 60
        return String(format: "%d:%02d /100m", min, sec)
    }
}
