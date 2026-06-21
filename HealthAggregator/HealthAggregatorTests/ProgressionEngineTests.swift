import XCTest
@testable import HealthAggregator

/// The progression engine is the "brain" of the workout flow. These tests lock in the
/// behavior of every strategy so a refactor can't silently change what the app tells users to lift.
final class ProgressionEngineTests: XCTestCase {

    // MARK: - First time

    func testFirstTimeWhenNoHistory() {
        let s = ProgressionEngine.suggestion(for: "Bench Press", rule: Fixture.rule(.doubleProgression), history: [])
        guard case .firstTime = s.action else { return XCTFail("Expected .firstTime, got \(s.action)") }
        XCTAssertFalse(s.isReadyToProgress)
        XCTAssertNil(s.suggestedWeightKg)
    }

    func testFirstTimeWhenExerciseNotInHistory() {
        let history = [Fixture.session(daysAgo: 2, exercise: "Squat", sets: [(100, 5), (100, 5), (100, 5)])]
        let s = ProgressionEngine.suggestion(for: "Bench Press", rule: Fixture.rule(.linearWeight), history: history)
        guard case .firstTime = s.action else { return XCTFail("Expected .firstTime") }
    }

    // MARK: - Double progression

    func testDoubleProgressionAllSetsHitMaxIncreasesWeight() {
        let rule = Fixture.rule(.doubleProgression, minReps: 5, maxReps: 8, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Curl", sets: [(20, 8), (20, 8), (20, 8)])]
        let s = ProgressionEngine.suggestion(for: "Curl", rule: rule, history: history)

        guard case .increaseWeight(let by) = s.action else { return XCTFail("Expected .increaseWeight, got \(s.action)") }
        XCTAssertEqual(by, rule.effectiveProgressionKg, accuracy: 0.001)
        XCTAssertEqual(s.suggestedWeightKg ?? 0, 20 + rule.effectiveProgressionKg, accuracy: 0.001)
        XCTAssertEqual(s.suggestedReps, rule.minReps, "After a weight bump, reps reset to the bottom of the range")
        XCTAssertTrue(s.isReadyToProgress)
    }

    func testDoubleProgressionHitMinNotMaxAddsRep() {
        let rule = Fixture.rule(.doubleProgression, minReps: 5, maxReps: 8, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Curl", sets: [(20, 6), (20, 6), (20, 6)])]
        let s = ProgressionEngine.suggestion(for: "Curl", rule: rule, history: history)

        guard case .increaseReps = s.action else { return XCTFail("Expected .increaseReps, got \(s.action)") }
        XCTAssertEqual(s.suggestedWeightKg ?? 0, 20, accuracy: 0.001, "Weight stays the same when adding reps")
        XCTAssertEqual(s.suggestedReps, 7)
        XCTAssertTrue(s.isReadyToProgress)
    }

    func testDoubleProgressionMissedSetsHolds() {
        let rule = Fixture.rule(.doubleProgression, minReps: 5, maxReps: 8, sets: 3)
        // Only two completed sets → didn't complete all 3 → hold
        let history = [Fixture.session(daysAgo: 2, exercise: "Curl", sets: [(20, 8), (20, 8)])]
        let s = ProgressionEngine.suggestion(for: "Curl", rule: rule, history: history)

        guard case .holdSteady = s.action else { return XCTFail("Expected .holdSteady, got \(s.action)") }
        XCTAssertFalse(s.isReadyToProgress)
    }

    // MARK: - Linear weight

    func testLinearWeightAllSetsCompleteIncreases() {
        let rule = Fixture.rule(.linearWeight, minReps: 5, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Squat", sets: [(100, 5), (100, 5), (100, 5)])]
        let s = ProgressionEngine.suggestion(for: "Squat", rule: rule, history: history)

        guard case .increaseWeight = s.action else { return XCTFail("Expected .increaseWeight, got \(s.action)") }
        XCTAssertEqual(s.suggestedWeightKg ?? 0, 100 + rule.effectiveProgressionKg, accuracy: 0.001)
        XCTAssertTrue(s.isReadyToProgress)
    }

    func testLinearWeightIncompleteHolds() {
        let rule = Fixture.rule(.linearWeight, minReps: 5, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Squat", sets: [(100, 5)])]
        let s = ProgressionEngine.suggestion(for: "Squat", rule: rule, history: history)
        guard case .holdSteady = s.action else { return XCTFail("Expected .holdSteady, got \(s.action)") }
        XCTAssertFalse(s.isReadyToProgress)
    }

    // MARK: - Rep range

    func testRepRangeAboveMaxIncreases() {
        let rule = Fixture.rule(.repRange, minReps: 8, maxReps: 12, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Row", sets: [(60, 12), (60, 12), (60, 13)])]
        let s = ProgressionEngine.suggestion(for: "Row", rule: rule, history: history)
        guard case .increaseWeight = s.action else { return XCTFail("Expected .increaseWeight, got \(s.action)") }
        XCTAssertEqual(s.suggestedReps, rule.minReps)
        XCTAssertTrue(s.isReadyToProgress)
    }

    func testRepRangeBelowMaxPushesReps() {
        // avg = 9 reps (below max of 12) — engine should push +2 reps toward the cap
        let rule = Fixture.rule(.repRange, minReps: 8, maxReps: 12, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Row", sets: [(60, 10), (60, 9), (60, 8)])]
        let s = ProgressionEngine.suggestion(for: "Row", rule: rule, history: history)
        guard case .increaseReps(let by) = s.action else { return XCTFail("Expected .increaseReps, got \(s.action)") }
        XCTAssertEqual(by, 2)
        XCTAssertEqual(s.suggestedReps, 11)   // avg 9 + 2
        XCTAssertTrue(s.isReadyToProgress)
    }

    func testRepRangeAtMaxButNotAllSetsHoldsUntilConsistent() {
        // avg = 12 (= maxReps) but one set was below — hold until all sets hit max
        let rule = Fixture.rule(.repRange, minReps: 8, maxReps: 12, sets: 3)
        let history = [Fixture.session(daysAgo: 2, exercise: "Row", sets: [(60, 10), (60, 12), (60, 14)])]
        let s = ProgressionEngine.suggestion(for: "Row", rule: rule, history: history)
        // 10 < 12 so allAboveMax is false; avg = 12 → repGain = 0 → holdSteady
        guard case .holdSteady = s.action else { return XCTFail("Expected .holdSteady, got \(s.action)") }
    }

    // MARK: - RPE / none

    func testRPEStrategyHoldsSteady() {
        let rule = Fixture.rule(.rpe)
        let history = [Fixture.session(daysAgo: 2, exercise: "Deadlift", sets: [(140, 5), (140, 5), (140, 5)])]
        let s = ProgressionEngine.suggestion(for: "Deadlift", rule: rule, history: history)
        guard case .holdSteady = s.action else { return XCTFail("Expected .holdSteady for RPE") }
    }

    // MARK: - Session population

    func testPopulateSessionFillsSetsFromRule() {
        let pe = ProgramExercise(exerciseName: "Bench Press", equipment: .barbell, orderIndex: 0,
                                 rule: Fixture.rule(.doubleProgression, sets: 4))
        let pw = ProgramWorkout(name: "Push", label: "A", type: .push, exercises: [pe])
        let session = ProgressionEngine.populateSession(programWorkout: pw, history: [])
        XCTAssertEqual(session.exercises.count, 1)
        XCTAssertEqual(session.exercises.first?.sets.count, 4, "Should create one set per rule.sets")
    }

    // MARK: - Swim

    func testSwimFirstTimeBaseline() {
        let s = ProgressionEngine.swimSuggestion(exerciseName: "Freestyle", history: [])
        XCTAssertFalse(s.isReadyToProgress)
        XCTAssertEqual(s.suggestedDistance, 100)
        XCTAssertNil(s.previousBestPace)
    }

    // MARK: - estimated 1RM (Epley)

    func testEstimated1RMEpley() {
        let set = WorkoutSet(setNumber: 1, weightKg: 100, reps: 5, isCompleted: true)
        // 100 * (1 + 5/30) = 116.67
        XCTAssertEqual(set.estimated1RM ?? 0, 116.667, accuracy: 0.01)
    }

    func testEstimated1RMNilForZeroReps() {
        let set = WorkoutSet(setNumber: 1, weightKg: 100, reps: 0)
        XCTAssertNil(set.estimated1RM)
    }
}
