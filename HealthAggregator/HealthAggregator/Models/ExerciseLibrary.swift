import Foundation

struct ExerciseDefinition: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: ExerciseCategory
    let muscleGroups: [String]
    let primaryEquipment: [Equipment]
    let isSwim: Bool

    init(_ name: String, _ category: ExerciseCategory, muscles: [String] = [],
         equipment: [Equipment] = [], isSwim: Bool = false) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.muscleGroups = muscles
        self.primaryEquipment = equipment
        self.isSwim = isSwim
    }

    // Default progression rule based on equipment
    var defaultRule: ProgressionRule {
        let eq = primaryEquipment.first ?? .bodyweight
        switch category {
        case .chest, .back, .shoulders, .legs:
            return ProgressionRule(strategy: .doubleProgression, equipment: eq, minReps: 5, maxReps: 8, sets: 4)
        case .arms:
            return ProgressionRule(strategy: .repRange, equipment: eq, minReps: 8, maxReps: 12, sets: 3)
        case .core:
            return ProgressionRule(strategy: .repRange, equipment: eq, minReps: 10, maxReps: 20, sets: 3)
        case .cardio, .swim:
            return ProgressionRule(strategy: .none, equipment: .bodyweight, minReps: 1, maxReps: 1, sets: 1)
        case .fullBody:
            return ProgressionRule(strategy: .doubleProgression, equipment: eq, minReps: 5, maxReps: 5, sets: 5)
        }
    }
}

enum ExerciseCategory: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"
    case swim = "Swim"
    case fullBody = "Full Body"
}

// MARK: - Library

enum ExerciseLibrary {
    static let all: [ExerciseDefinition] = chest + back + shoulders + arms + legs + core + swim + cardio

    // MARK: Chest
    static let chest: [ExerciseDefinition] = [
        .init("Bench Press", .chest, muscles: ["Chest", "Triceps", "Front Delts"], equipment: [.barbell]),
        .init("Incline Bench Press", .chest, muscles: ["Upper Chest", "Triceps"], equipment: [.barbell]),
        .init("Decline Bench Press", .chest, muscles: ["Lower Chest", "Triceps"], equipment: [.barbell]),
        .init("Close-Grip Bench Press", .chest, muscles: ["Triceps", "Chest"], equipment: [.barbell]),
        .init("Dumbbell Bench Press", .chest, muscles: ["Chest", "Triceps"], equipment: [.dumbbell]),
        .init("Incline Dumbbell Press", .chest, muscles: ["Upper Chest", "Triceps"], equipment: [.dumbbell]),
        .init("Dumbbell Fly", .chest, muscles: ["Chest"], equipment: [.dumbbell]),
        .init("Cable Fly", .chest, muscles: ["Chest"], equipment: [.cable]),
        .init("Cable Crossover", .chest, muscles: ["Chest"], equipment: [.cable]),
        .init("Machine Chest Press", .chest, muscles: ["Chest", "Triceps"], equipment: [.machine]),
        .init("Machine Fly / Pec Deck", .chest, muscles: ["Chest"], equipment: [.machine]),
        .init("Smith Machine Bench Press", .chest, muscles: ["Chest", "Triceps"], equipment: [.smithMachine]),
        .init("Push-Up", .chest, muscles: ["Chest", "Triceps", "Core"], equipment: [.bodyweight]),
        .init("Dips", .chest, muscles: ["Chest", "Triceps"], equipment: [.bodyweight]),
    ]

    // MARK: Back
    static let back: [ExerciseDefinition] = [
        .init("Deadlift", .back, muscles: ["Lower Back", "Hamstrings", "Glutes", "Traps"], equipment: [.barbell]),
        .init("Romanian Deadlift", .back, muscles: ["Hamstrings", "Glutes", "Lower Back"], equipment: [.barbell]),
        .init("Sumo Deadlift", .back, muscles: ["Inner Thighs", "Glutes", "Lower Back"], equipment: [.barbell]),
        .init("Trap Bar Deadlift", .back, muscles: ["Lower Back", "Quads", "Hamstrings"], equipment: [.trapBar]),
        .init("Barbell Row", .back, muscles: ["Mid Back", "Lats", "Biceps"], equipment: [.barbell]),
        .init("Pendlay Row", .back, muscles: ["Mid Back", "Lats"], equipment: [.barbell]),
        .init("T-Bar Row", .back, muscles: ["Mid Back", "Lats"], equipment: [.barbell]),
        .init("Dumbbell Row", .back, muscles: ["Lats", "Mid Back"], equipment: [.dumbbell]),
        .init("Pull-Up", .back, muscles: ["Lats", "Biceps"], equipment: [.bodyweight]),
        .init("Chin-Up", .back, muscles: ["Lats", "Biceps"], equipment: [.bodyweight]),
        .init("Weighted Pull-Up", .back, muscles: ["Lats", "Biceps"], equipment: [.barbell]),
        .init("Lat Pulldown", .back, muscles: ["Lats", "Biceps"], equipment: [.cable]),
        .init("Seated Cable Row", .back, muscles: ["Mid Back", "Lats", "Biceps"], equipment: [.cable]),
        .init("Single-Arm Cable Row", .back, muscles: ["Mid Back", "Lats"], equipment: [.cable]),
        .init("Machine Row", .back, muscles: ["Mid Back", "Lats"], equipment: [.machine]),
        .init("Machine Lat Pulldown", .back, muscles: ["Lats"], equipment: [.machine]),
        .init("Hyperextension", .back, muscles: ["Lower Back", "Glutes"], equipment: [.machine]),
        .init("Good Morning", .back, muscles: ["Lower Back", "Hamstrings"], equipment: [.barbell]),
    ]

    // MARK: Shoulders
    static let shoulders: [ExerciseDefinition] = [
        .init("Overhead Press", .shoulders, muscles: ["Delts", "Triceps"], equipment: [.barbell]),
        .init("Push Press", .shoulders, muscles: ["Delts", "Triceps"], equipment: [.barbell]),
        .init("Dumbbell Shoulder Press", .shoulders, muscles: ["Delts", "Triceps"], equipment: [.dumbbell]),
        .init("Arnold Press", .shoulders, muscles: ["All Three Delt Heads"], equipment: [.dumbbell]),
        .init("Machine Shoulder Press", .shoulders, muscles: ["Delts", "Triceps"], equipment: [.machine]),
        .init("Lateral Raise", .shoulders, muscles: ["Side Delts"], equipment: [.dumbbell]),
        .init("Cable Lateral Raise", .shoulders, muscles: ["Side Delts"], equipment: [.cable]),
        .init("Machine Lateral Raise", .shoulders, muscles: ["Side Delts"], equipment: [.machine]),
        .init("Front Raise", .shoulders, muscles: ["Front Delts"], equipment: [.dumbbell]),
        .init("Face Pull", .shoulders, muscles: ["Rear Delts", "Rotator Cuff"], equipment: [.cable]),
        .init("Rear Delt Fly", .shoulders, muscles: ["Rear Delts"], equipment: [.dumbbell]),
        .init("Reverse Pec Deck", .shoulders, muscles: ["Rear Delts"], equipment: [.machine]),
        .init("Upright Row", .shoulders, muscles: ["Side Delts", "Traps"], equipment: [.barbell]),
    ]

    // MARK: Arms
    static let arms: [ExerciseDefinition] = [
        .init("Barbell Curl", .arms, muscles: ["Biceps"], equipment: [.barbell]),
        .init("EZ Bar Curl", .arms, muscles: ["Biceps"], equipment: [.ezBar]),
        .init("Dumbbell Curl", .arms, muscles: ["Biceps"], equipment: [.dumbbell]),
        .init("Incline Dumbbell Curl", .arms, muscles: ["Long Head Biceps"], equipment: [.dumbbell]),
        .init("Hammer Curl", .arms, muscles: ["Biceps", "Brachialis"], equipment: [.dumbbell]),
        .init("Cable Curl", .arms, muscles: ["Biceps"], equipment: [.cable]),
        .init("Preacher Curl", .arms, muscles: ["Biceps"], equipment: [.barbell, .ezBar]),
        .init("Machine Curl", .arms, muscles: ["Biceps"], equipment: [.machine]),
        .init("Concentration Curl", .arms, muscles: ["Biceps"], equipment: [.dumbbell]),
        .init("Tricep Pushdown (Rope)", .arms, muscles: ["Triceps"], equipment: [.cable]),
        .init("Tricep Pushdown (Bar)", .arms, muscles: ["Triceps"], equipment: [.cable]),
        .init("Overhead Tricep Extension", .arms, muscles: ["Long Head Triceps"], equipment: [.dumbbell, .cable]),
        .init("Skull Crusher", .arms, muscles: ["Triceps"], equipment: [.barbell, .ezBar]),
        .init("Close-Grip Push-Up", .arms, muscles: ["Triceps"], equipment: [.bodyweight]),
        .init("Machine Tricep Extension", .arms, muscles: ["Triceps"], equipment: [.machine]),
    ]

    // MARK: Legs
    static let legs: [ExerciseDefinition] = [
        .init("Back Squat", .legs, muscles: ["Quads", "Glutes", "Hamstrings", "Core"], equipment: [.barbell]),
        .init("Front Squat", .legs, muscles: ["Quads", "Core"], equipment: [.barbell]),
        .init("Paused Squat", .legs, muscles: ["Quads", "Glutes"], equipment: [.barbell]),
        .init("Leg Press", .legs, muscles: ["Quads", "Glutes"], equipment: [.machine]),
        .init("Hack Squat", .legs, muscles: ["Quads"], equipment: [.machine]),
        .init("Smith Machine Squat", .legs, muscles: ["Quads", "Glutes"], equipment: [.smithMachine]),
        .init("Goblet Squat", .legs, muscles: ["Quads", "Glutes", "Core"], equipment: [.dumbbell, .kettlebell]),
        .init("Bulgarian Split Squat", .legs, muscles: ["Quads", "Glutes"], equipment: [.dumbbell, .barbell]),
        .init("Lunge", .legs, muscles: ["Quads", "Glutes"], equipment: [.dumbbell, .barbell]),
        .init("Walking Lunge", .legs, muscles: ["Quads", "Glutes"], equipment: [.dumbbell]),
        .init("Step-Up", .legs, muscles: ["Quads", "Glutes"], equipment: [.dumbbell]),
        .init("Leg Extension", .legs, muscles: ["Quads"], equipment: [.machine]),
        .init("Leg Curl (Lying)", .legs, muscles: ["Hamstrings"], equipment: [.machine]),
        .init("Leg Curl (Seated)", .legs, muscles: ["Hamstrings"], equipment: [.machine]),
        .init("Nordic Curl", .legs, muscles: ["Hamstrings"], equipment: [.bodyweight]),
        .init("Hip Thrust", .legs, muscles: ["Glutes", "Hamstrings"], equipment: [.barbell]),
        .init("Cable Pull-Through", .legs, muscles: ["Glutes", "Hamstrings"], equipment: [.cable]),
        .init("Glute Bridge", .legs, muscles: ["Glutes"], equipment: [.barbell, .bodyweight]),
        .init("Calf Raise (Standing)", .legs, muscles: ["Calves"], equipment: [.machine, .barbell]),
        .init("Calf Raise (Seated)", .legs, muscles: ["Calves", "Soleus"], equipment: [.machine]),
        .init("Calf Raise (Leg Press)", .legs, muscles: ["Calves"], equipment: [.machine]),
    ]

    // MARK: Core
    static let core: [ExerciseDefinition] = [
        .init("Plank", .core, muscles: ["Core", "Abs"], equipment: [.bodyweight]),
        .init("Side Plank", .core, muscles: ["Obliques"], equipment: [.bodyweight]),
        .init("Ab Rollout", .core, muscles: ["Abs", "Core"], equipment: [.barbell]),
        .init("Cable Crunch", .core, muscles: ["Abs"], equipment: [.cable]),
        .init("Hanging Leg Raise", .core, muscles: ["Abs", "Hip Flexors"], equipment: [.bodyweight]),
        .init("Decline Sit-Up", .core, muscles: ["Abs"], equipment: [.bodyweight]),
        .init("Russian Twist", .core, muscles: ["Obliques"], equipment: [.dumbbell, .bodyweight]),
        .init("Dead Bug", .core, muscles: ["Core"], equipment: [.bodyweight]),
        .init("Landmine Rotation", .core, muscles: ["Obliques", "Core"], equipment: [.barbell]),
        .init("Pallof Press", .core, muscles: ["Core", "Obliques"], equipment: [.cable]),
    ]

    // MARK: Swim
    static let swim: [ExerciseDefinition] = [
        .init("Freestyle", .swim, isSwim: true),
        .init("Backstroke", .swim, isSwim: true),
        .init("Breaststroke", .swim, isSwim: true),
        .init("Butterfly", .swim, isSwim: true),
        .init("Individual Medley", .swim, isSwim: true),
        .init("Kickboard", .swim, isSwim: true),
        .init("Pull Buoy", .swim, isSwim: true),
        .init("Drill", .swim, isSwim: true),
        .init("Catch-Up Drill", .swim, isSwim: true),
        .init("Fingertip Drag Drill", .swim, isSwim: true),
    ]

    // MARK: Cardio
    static let cardio: [ExerciseDefinition] = [
        .init("Running", .cardio, equipment: [.bodyweight]),
        .init("Cycling", .cardio, equipment: [.machine]),
        .init("Rowing Machine", .cardio, equipment: [.machine]),
        .init("Elliptical", .cardio, equipment: [.machine]),
        .init("Jump Rope", .cardio, equipment: [.band]),
        .init("Assault Bike", .cardio, equipment: [.machine]),
    ]

    // MARK: - Default templates (for Quick Start grid)

    static var defaultTemplates: [WorkoutTemplate] {
        builtInPrograms.prefix(2).flatMap { prog in
            prog.workouts.prefix(3).map { pw in
                var t = WorkoutTemplate(name: "\(pw.label) — \(pw.name)", type: pw.type)
                t.exercises = pw.exercises.map { pe in
                    TemplateExercise(name: pe.exerciseName, orderIndex: pe.orderIndex,
                                     defaultSets: pe.rule.sets, defaultReps: pe.rule.minReps)
                }
                return t
            }
        }
    }

    // MARK: - Search

    static func search(_ query: String) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    static func byCategory(_ category: ExerciseCategory) -> [ExerciseDefinition] {
        all.filter { $0.category == category }
    }

    static func byEquipment(_ equipment: Equipment) -> [ExerciseDefinition] {
        all.filter { $0.primaryEquipment.contains(equipment) }
    }

    static func find(_ name: String) -> ExerciseDefinition? {
        all.first { $0.name == name }
    }

    // MARK: - Built-in Programs

    static let builtInPrograms: [TrainingProgram] = [
        strongerABC, pplProgram, upperLowerProgram, swimProgram
    ]

    static var strongerABC: TrainingProgram {
        var p = TrainingProgram(name: "Stronger A/B/C", description: "3-day rotating strength program. Big compound lifts, linear progression.", daysPerWeek: 3, goal: .strength)
        p.workouts = [
            makeProgramWorkout(label: "A", name: "Squat Focus", type: .legs, exercises: [
                pe("Back Squat", eq: .barbell, sets: 5, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Romanian Deadlift", eq: .barbell, sets: 3, reps: 8, maxReps: 10, strategy: .doubleProgression),
                pe("Leg Press", eq: .machine, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Leg Curl (Lying)", eq: .machine, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Calf Raise (Standing)", eq: .machine, sets: 4, reps: 12, maxReps: 20, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "B", name: "Push / Press", type: .push, exercises: [
                pe("Bench Press", eq: .barbell, sets: 5, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Overhead Press", eq: .barbell, sets: 3, reps: 5, maxReps: 8, strategy: .doubleProgression),
                pe("Incline Dumbbell Press", eq: .dumbbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Lateral Raise", eq: .dumbbell, sets: 3, reps: 12, maxReps: 20, strategy: .repRange),
                pe("Tricep Pushdown (Rope)", eq: .cable, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Skull Crusher", eq: .barbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "C", name: "Pull / Hinge", type: .pull, exercises: [
                pe("Deadlift", eq: .barbell, sets: 5, reps: 3, maxReps: 5, strategy: .linearWeight),
                pe("Barbell Row", eq: .barbell, sets: 4, reps: 5, maxReps: 8, strategy: .doubleProgression),
                pe("Pull-Up", eq: .bodyweight, sets: 3, reps: 5, maxReps: 10, strategy: .doubleProgression),
                pe("Seated Cable Row", eq: .cable, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Face Pull", eq: .cable, sets: 3, reps: 15, maxReps: 20, strategy: .repRange),
                pe("Barbell Curl", eq: .barbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Hammer Curl", eq: .dumbbell, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
            ]),
        ]
        return p
    }

    static var pplProgram: TrainingProgram {
        var p = TrainingProgram(name: "Push / Pull / Legs", description: "6-day PPL for hypertrophy. Pairs well with 3x/week if needed.", daysPerWeek: 6, goal: .hypertrophy)
        p.workouts = [
            makeProgramWorkout(label: "P1", name: "Push — Strength", type: .push, exercises: [
                pe("Bench Press", eq: .barbell, sets: 4, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Overhead Press", eq: .barbell, sets: 3, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Incline Dumbbell Press", eq: .dumbbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Cable Fly", eq: .cable, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Lateral Raise", eq: .dumbbell, sets: 4, reps: 15, maxReps: 20, strategy: .repRange),
                pe("Overhead Tricep Extension", eq: .cable, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Tricep Pushdown (Rope)", eq: .cable, sets: 3, reps: 12, maxReps: 15, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "P2", name: "Pull — Strength", type: .pull, exercises: [
                pe("Deadlift", eq: .barbell, sets: 3, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Pull-Up", eq: .bodyweight, sets: 3, reps: 5, maxReps: 10, strategy: .doubleProgression),
                pe("Barbell Row", eq: .barbell, sets: 3, reps: 5, maxReps: 8, strategy: .doubleProgression),
                pe("Lat Pulldown", eq: .cable, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Face Pull", eq: .cable, sets: 3, reps: 15, maxReps: 20, strategy: .repRange),
                pe("Barbell Curl", eq: .barbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Hammer Curl", eq: .dumbbell, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "L", name: "Legs", type: .legs, exercises: [
                pe("Back Squat", eq: .barbell, sets: 4, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Romanian Deadlift", eq: .barbell, sets: 3, reps: 8, maxReps: 10, strategy: .doubleProgression),
                pe("Leg Press", eq: .machine, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Leg Extension", eq: .machine, sets: 3, reps: 12, maxReps: 20, strategy: .repRange),
                pe("Leg Curl (Seated)", eq: .machine, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Hip Thrust", eq: .barbell, sets: 3, reps: 10, maxReps: 15, strategy: .doubleProgression),
                pe("Calf Raise (Standing)", eq: .machine, sets: 4, reps: 15, maxReps: 25, strategy: .repRange),
            ]),
        ]
        return p
    }

    static var upperLowerProgram: TrainingProgram {
        var p = TrainingProgram(name: "Upper / Lower", description: "4-day split alternating upper and lower body.", daysPerWeek: 4, goal: .strength)
        p.workouts = [
            makeProgramWorkout(label: "U1", name: "Upper — Heavy", type: .upper, exercises: [
                pe("Bench Press", eq: .barbell, sets: 4, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Barbell Row", eq: .barbell, sets: 4, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Overhead Press", eq: .barbell, sets: 3, reps: 5, maxReps: 8, strategy: .doubleProgression),
                pe("Pull-Up", eq: .bodyweight, sets: 3, reps: 5, maxReps: 10, strategy: .doubleProgression),
                pe("Lateral Raise", eq: .dumbbell, sets: 3, reps: 12, maxReps: 20, strategy: .repRange),
                pe("Barbell Curl", eq: .barbell, sets: 2, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Tricep Pushdown (Rope)", eq: .cable, sets: 2, reps: 10, maxReps: 15, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "L1", name: "Lower — Squat", type: .legs, exercises: [
                pe("Back Squat", eq: .barbell, sets: 4, reps: 5, maxReps: 5, strategy: .linearWeight),
                pe("Romanian Deadlift", eq: .barbell, sets: 3, reps: 8, maxReps: 10, strategy: .doubleProgression),
                pe("Leg Press", eq: .machine, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Leg Curl (Lying)", eq: .machine, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Calf Raise (Standing)", eq: .machine, sets: 3, reps: 15, maxReps: 25, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "U2", name: "Upper — Volume", type: .upper, exercises: [
                pe("Incline Dumbbell Press", eq: .dumbbell, sets: 4, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Seated Cable Row", eq: .cable, sets: 4, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Dumbbell Shoulder Press", eq: .dumbbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Lat Pulldown", eq: .cable, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Cable Fly", eq: .cable, sets: 3, reps: 12, maxReps: 15, strategy: .repRange),
                pe("Face Pull", eq: .cable, sets: 3, reps: 15, maxReps: 20, strategy: .repRange),
                pe("Dumbbell Curl", eq: .dumbbell, sets: 3, reps: 10, maxReps: 15, strategy: .repRange),
                pe("Skull Crusher", eq: .barbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
            ]),
            makeProgramWorkout(label: "L2", name: "Lower — Deadlift", type: .legs, exercises: [
                pe("Deadlift", eq: .barbell, sets: 4, reps: 4, maxReps: 5, strategy: .linearWeight),
                pe("Bulgarian Split Squat", eq: .dumbbell, sets: 3, reps: 8, maxReps: 12, strategy: .repRange),
                pe("Leg Extension", eq: .machine, sets: 3, reps: 12, maxReps: 20, strategy: .repRange),
                pe("Hip Thrust", eq: .barbell, sets: 3, reps: 10, maxReps: 15, strategy: .doubleProgression),
                pe("Calf Raise (Seated)", eq: .machine, sets: 3, reps: 15, maxReps: 25, strategy: .repRange),
            ]),
        ]
        return p
    }

    static var swimProgram: TrainingProgram {
        var p = TrainingProgram(name: "Swim Fitness", description: "3-day swim program alternating endurance, speed, and technique.", daysPerWeek: 3, goal: .swim)
        p.workouts = [
            makeProgramWorkout(label: "A", name: "Endurance", type: .poolSwim, exercises: [
                swimPE("Freestyle", distance: 400, sets: 1, stroke: .freestyle, notes: "Warm up — easy pace"),
                swimPE("Freestyle", distance: 100, sets: 8, stroke: .freestyle, notes: "Main set — moderate effort, 20s rest"),
                swimPE("Kickboard", distance: 50, sets: 4, stroke: .freestyle, notes: "Kick set"),
                swimPE("Backstroke", distance: 100, sets: 2, stroke: .backstroke, notes: "Cool down"),
            ]),
            makeProgramWorkout(label: "B", name: "Speed / Intervals", type: .poolSwim, exercises: [
                swimPE("Freestyle", distance: 200, sets: 1, stroke: .freestyle, notes: "Warm up"),
                swimPE("Freestyle", distance: 50, sets: 10, stroke: .freestyle, notes: "Sprint — max effort, 30s rest"),
                swimPE("Breaststroke", distance: 50, sets: 4, stroke: .breaststroke, notes: "Technique"),
                swimPE("Freestyle", distance: 100, sets: 1, stroke: .freestyle, notes: "Cool down"),
            ]),
            makeProgramWorkout(label: "C", name: "Technique / Mixed", type: .poolSwim, exercises: [
                swimPE("Catch-Up Drill", distance: 200, sets: 1, stroke: .freestyle, notes: "Warm up drill"),
                swimPE("Individual Medley", distance: 100, sets: 4, stroke: .medley, notes: "All four strokes"),
                swimPE("Pull Buoy", distance: 200, sets: 2, stroke: .pull, notes: "Arms only — focus on pull"),
                swimPE("Freestyle", distance: 200, sets: 1, stroke: .freestyle, notes: "Cool down — easy"),
            ]),
        ]
        return p
    }

    // MARK: - Helpers

    private static func pe(_ name: String, eq: Equipment, sets: Int, reps: Int, maxReps: Int, strategy: ProgressionStrategy) -> ProgramExercise {
        let rule = ProgressionRule(strategy: strategy, equipment: eq, minReps: reps, maxReps: maxReps, sets: sets)
        return ProgramExercise(exerciseName: name, equipment: eq, orderIndex: 0, rule: rule,
                               muscleGroups: find(name)?.muscleGroups ?? [])
    }

    private static func swimPE(_ name: String, distance: Double, sets: Int, stroke: StrokeType, notes: String = "") -> ProgramExercise {
        let rule = ProgressionRule(strategy: .none, equipment: .bodyweight, minReps: 1, maxReps: 1, sets: sets)
        return ProgramExercise(exerciseName: name, equipment: .bodyweight, orderIndex: 0, rule: rule,
                               notes: notes, isSwim: true, swimDistance: distance, swimStroke: stroke)
    }

    private static func makeProgramWorkout(label: String, name: String, type: WorkoutType, exercises: [ProgramExercise]) -> ProgramWorkout {
        var w = ProgramWorkout(name: name, label: label, type: type)
        w.exercises = exercises.enumerated().map { i, ex in
            var e = ex; e.orderIndex = i; return e
        }
        return w
    }
}
