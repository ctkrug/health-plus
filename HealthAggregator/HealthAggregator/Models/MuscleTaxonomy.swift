import Foundation
import MuscleMap

/// The app's canonical muscle taxonomy is `MuscleMap.Muscle` (from the third-party `MuscleMap`
/// package, MIT-licensed) — not a parallel enum. `ExerciseLibrary.muscleGroups` predates this
/// integration and stores free-text labels ("Front Delts", "Mid Back", ...); this file is the one
/// normalization layer that maps those labels onto `Muscle` cases so every downstream consumer
/// (superset pairing, the muscle-balance engine, the interactive body map) shares one taxonomy.
///
/// Known gaps, reconciled against the package's actual case set (see docs/SPEC-lift-charts-and-muscle-map.md §2.3):
/// - No dedicated "lats" case — `Muscle.upperBack` is the closest region; "Lats" and "Mid Back"
///   both map there.
/// - No lateral/side-deltoid subgroup (only `frontDeltoid`/`rearDeltoid`) — "Side Delts" maps to
///   the parent `.deltoids`.
/// - "Brachialis" and "Soleus" have no dedicated case — they map to their prime-mover parent
///   (`.biceps`, `.calves`) since that's what's actually trained.
enum MuscleTaxonomy {
    /// Maps a free-text `ExerciseLibrary` muscle label to its `Muscle` case. Case-insensitive.
    /// Returns nil for labels this taxonomy doesn't recognize (logged nowhere — callers should
    /// treat nil as "skip", not fail).
    static func canonicalize(_ raw: String) -> Muscle? {
        rawToMuscle[raw.lowercased()]
    }

    private static let rawToMuscle: [String: Muscle] = [
        "chest": .chest,
        "upper chest": .upperChest,
        "lower chest": .lowerChest,
        "triceps": .triceps,
        "long head triceps": .triceps,
        "front delts": .frontDeltoid,
        "rear delts": .rearDeltoid,
        "side delts": .deltoids,
        "delts": .deltoids,
        "all three delt heads": .deltoids,
        "rotator cuff": .rotatorCuff,
        "core": .abs,
        "abs": .abs,
        "obliques": .obliques,
        "hip flexors": .hipFlexors,
        "lower back": .lowerBack,
        "hamstrings": .hamstring,
        "glutes": .gluteal,
        "traps": .trapezius,
        "inner thighs": .adductors,
        "quads": .quadriceps,
        "mid back": .upperBack,
        "lats": .upperBack,
        "brachialis": .biceps,
        "long head biceps": .biceps,
        "biceps": .biceps,
        "calves": .calves,
        "soleus": .calves,
    ]
}

extension Muscle {
    /// Which muscle the balance engine attributes volume to. Subgroups the body diagram only
    /// renders with `.showSubGroups()` collapse to their parent here — matching the diagram's own
    /// default tap-resolves-to-parent behavior (see `Muscle.isAlwaysVisibleSubGroup`). Subgroups
    /// that render independently by default (`adductors`, `ankles`, `neck`) stay distinct.
    var balanceGroup: Muscle {
        guard isSubGroup, !isAlwaysVisibleSubGroup, let parent = parentGroup else { return self }
        return parent
    }
}

extension ExerciseDefinition {
    /// The exercise's primary canonical muscle (first entry in `muscleGroups`, if recognized).
    var primaryCanonicalMuscle: Muscle? {
        muscleGroups.first.flatMap(MuscleTaxonomy.canonicalize)
    }

    /// Secondary canonical muscles — every other recognized, distinct entry in `muscleGroups`.
    var secondaryCanonicalMuscles: [Muscle] {
        guard muscleGroups.count > 1 else { return [] }
        let primary = primaryCanonicalMuscle
        var seen = Set<Muscle>()
        return muscleGroups.dropFirst().compactMap(MuscleTaxonomy.canonicalize).filter { m in
            guard m != primary, !seen.contains(m) else { return false }
            seen.insert(m)
            return true
        }
    }
}
