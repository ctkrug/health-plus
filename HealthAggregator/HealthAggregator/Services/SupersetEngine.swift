import Foundation

// MARK: - Movement Pattern

/// Movement-pattern classification used for antagonist superset pairing.
/// See docs/SCIENCE.md §10 for the science behind each pairing.
enum MovementPattern: String, CaseIterable {
    case horizontalPush  = "Horizontal Push"   // bench, chest press
    case horizontalPull  = "Horizontal Pull"   // rows, rear delt
    case verticalPush    = "Vertical Push"     // OHP, shoulder press
    case verticalPull    = "Vertical Pull"     // lat pulldown, pull-up
    case elbowFlexion    = "Biceps"            // curls
    case elbowExtension  = "Triceps"           // pushdowns, extensions
    case kneeDominant    = "Quads / Legs"      // squats, leg press, lunges, leg ext
    case hipDominant     = "Hamstrings / Glutes" // RDL, hip thrust, leg curl
    case shoulderAnt     = "Front / Side Delts" // front raises, lateral raises
    case shoulderPost    = "Rear Delts"        // rear delt fly, face pull
    case calves          = "Calves"
    case core            = "Core"
    case other           = "Other"
}

// MARK: - Superset Pair

struct SupersetPair: Identifiable {
    let id = UUID()
    let a: TemplateExercise
    let b: TemplateExercise
    let score: Int         // 3 = direct antagonist, 2 = partial, 1 = non-competing
    let label: String      // human-readable reason, e.g. "Horizontal Push ↔ Pull"

    var quality: PairQuality {
        switch score {
        case 3: return .antagonist
        case 2: return .partial
        default: return .nonCompeting
        }
    }
}

enum PairQuality {
    case antagonist    // max benefit — performance boost on 2nd exercise
    case partial       // complementary, moderate benefit
    case nonCompeting  // time-efficient only, no PAP benefit

    var label: String {
        switch self {
        case .antagonist:   return "Antagonist"
        case .partial:      return "Complementary"
        case .nonCompeting: return "Non-competing"
        }
    }

    var description: String {
        switch self {
        case .antagonist:
            return "Opposing muscles — expect 5–15% more reps on the 2nd exercise."
        case .partial:
            return "Complementary pair — shares rest time efficiently."
        case .nonCompeting:
            return "Unrelated muscles — saves time; no performance boost."
        }
    }

    var colorHex: String {
        switch self {
        case .antagonist:   return "#22C55E"
        case .partial:      return "#F59E0B"
        case .nonCompeting: return "#6366F1"
        }
    }
}

// MARK: - Engine

enum SupersetEngine {

    // MARK: Public API

    /// Rank all exercise pairs in a workout by superset suitability.
    /// Returns pairs sorted best-first, filtered to score ≥ 1, at most `limit`.
    static func recommendations(
        for exercises: [TemplateExercise],
        limit: Int = 5
    ) -> [SupersetPair] {
        var pairs: [SupersetPair] = []
        for i in exercises.indices {
            for j in (i + 1)..<exercises.count {
                let a = exercises[i], b = exercises[j]
                let pA = classify(a), pB = classify(b)
                guard let pair = score(a: a, b: b, pA: pA, pB: pB) else { continue }
                pairs.append(pair)
            }
        }
        return Array(pairs.sorted { $0.score > $1.score }.prefix(limit))
    }

    // MARK: Classification

    /// Classify an exercise's primary movement pattern.
    static func classify(_ exercise: TemplateExercise) -> MovementPattern {
        // Prefer library muscle groups (most reliable)
        if let def = ExerciseLibrary.find(exercise.name) {
            return patternFromMuscles(def.muscleGroups, name: exercise.name)
        }
        // Fallback: keyword match on the exercise name
        return patternFromName(exercise.name)
    }

    // MARK: Private helpers

    private static func score(
        a: TemplateExercise, b: TemplateExercise,
        pA: MovementPattern, pB: MovementPattern
    ) -> SupersetPair? {
        if pA == pB { return nil }  // same pattern — never recommended

        // Direct antagonist pairs (score 3)
        let antagonists: [(MovementPattern, MovementPattern, String)] = [
            (.horizontalPush, .horizontalPull,  "Horizontal Push ↔ Pull"),
            (.verticalPush,   .verticalPull,    "Vertical Push ↔ Pull"),
            (.elbowFlexion,   .elbowExtension,  "Biceps ↔ Triceps"),
            (.kneeDominant,   .hipDominant,     "Quads ↔ Hamstrings"),
        ]
        for (x, y, label) in antagonists {
            if (pA == x && pB == y) || (pA == y && pB == x) {
                return SupersetPair(a: a, b: b, score: 3, label: label)
            }
        }

        // Partial pairs (score 2)
        let partial: [(MovementPattern, MovementPattern, String)] = [
            (.shoulderAnt,  .shoulderPost,  "Front ↔ Rear Delts"),
            (.horizontalPush, .shoulderPost, "Chest ↔ Rear Delts"),
        ]
        for (x, y, label) in partial {
            if (pA == x && pB == y) || (pA == y && pB == x) {
                return SupersetPair(a: a, b: b, score: 2, label: label)
            }
        }

        // Non-competing: upper vs lower (score 1)
        let upper: Set<MovementPattern> = [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .elbowFlexion, .elbowExtension, .shoulderAnt, .shoulderPost]
        let lower: Set<MovementPattern> = [.kneeDominant, .hipDominant, .calves]
        if (upper.contains(pA) && lower.contains(pB)) || (lower.contains(pA) && upper.contains(pB)) {
            return SupersetPair(a: a, b: b, score: 1, label: "Upper ↔ Lower body")
        }

        return nil
    }

    // Keyword-based name classifier (fallback for user-created exercises)
    private static func patternFromName(_ name: String) -> MovementPattern {
        let n = name.lowercased()

        // Horizontal push
        if n.contains("bench") || n.contains("chest press") || n.contains("push-up") || n.contains("pushup") || n.contains("dip") || n.contains("incline") && n.contains("press") {
            return .horizontalPush
        }
        // Horizontal pull
        if n.contains("row") || n.contains("rear delt") || n.contains("face pull") || n.contains("reverse fly") || n.contains("reverse pec") {
            return .horizontalPull
        }
        // Vertical push
        if n.contains("overhead press") || n.contains("ohp") || n.contains("shoulder press") || n.contains("arnold") || n.contains("push press") {
            return .verticalPush
        }
        // Vertical pull
        if n.contains("pull-up") || n.contains("pullup") || n.contains("chin-up") || n.contains("chinup") || n.contains("lat pull") || n.contains("pulldown") {
            return .verticalPull
        }
        // Biceps
        if n.contains("curl") && !n.contains("leg curl") {
            return .elbowFlexion
        }
        // Triceps
        if n.contains("tricep") || n.contains("pushdown") || n.contains("skull") || n.contains("dip") {
            return .elbowExtension
        }
        // Quads/legs
        if n.contains("squat") || n.contains("leg press") || n.contains("lunge") || n.contains("leg extension") || n.contains("step-up") || n.contains("split squat") || n.contains("hack squat") {
            return .kneeDominant
        }
        // Hamstrings/glutes
        if n.contains("deadlift") || n.contains("rdl") || n.contains("hip thrust") || n.contains("leg curl") || n.contains("glute") || n.contains("nordic") || n.contains("good morning") {
            return .hipDominant
        }
        // Lateral/shoulder isolation
        if n.contains("lateral raise") || n.contains("front raise") {
            return .shoulderAnt
        }
        // Calves
        if n.contains("calf") || n.contains("calve") {
            return .calves
        }
        // Core
        if n.contains("plank") || n.contains("crunch") || n.contains("ab ") || n.contains("core") || n.contains("sit-up") {
            return .core
        }

        return .other
    }

    // Muscle-group-based classifier (primary path — more accurate)
    private static func patternFromMuscles(_ muscles: [String], name: String) -> MovementPattern {
        let m = muscles.map { $0.lowercased() }
        let n = name.lowercased()

        // Biceps / Triceps isolations take priority when exercise name signals it
        if (m.contains("biceps") || m.contains("brachialis")) && (n.contains("curl")) {
            return .elbowFlexion
        }
        if m.contains("triceps") && (n.contains("extension") || n.contains("pushdown") || n.contains("skull") || n.contains("dip")) {
            return .elbowExtension
        }

        // Primary movers determine pattern for compound movements
        if m.contains("lats") || m.contains("mid back") {
            // Is it a row (horizontal) or a pulldown (vertical)?
            if n.contains("pulldown") || n.contains("pull-up") || n.contains("pullup") || n.contains("chin") {
                return .verticalPull
            }
            return .horizontalPull
        }
        if m.contains("chest") {
            return .horizontalPush
        }
        if m.contains("quads") {
            return .kneeDominant
        }
        if m.contains("hamstrings") || m.contains("glutes") && (n.contains("deadlift") || n.contains("rdl") || n.contains("thrust") || n.contains("curl")) {
            return .hipDominant
        }
        if m.contains("glutes") {
            return .hipDominant
        }
        if (m.contains("delts") || m.contains("all three delt heads")) && (n.contains("press") || n.contains("push")) {
            return .verticalPush
        }
        if m.contains("side delts") || m.contains("front delts") {
            return .shoulderAnt
        }
        if m.contains("rear delts") {
            return .shoulderPost
        }
        if m.contains("calves") || m.contains("soleus") {
            return .calves
        }
        if m.contains("abs") || m.contains("core") || m.contains("obliques") {
            return .core
        }

        // Fallback to name keywords
        return patternFromName(name)
    }
}
