import XCTest
@testable import HealthAggregator

/// WorkoutStore seeds built-in content and tracks PRs/streaks. These tests verify the seed
/// invariants and the public PR/streak surface without reaching into Core Data internals.
final class WorkoutStoreTests: XCTestCase {

    func testSeedsTemplatesAndPrograms() {
        let store = WorkoutStore()
        XCTAssertFalse(store.templates.isEmpty, "Default templates should be seeded")
        XCTAssertFalse(store.programs.isEmpty, "Built-in programs should be seeded")
    }

    func testExactlyOneActiveProgram() {
        let store = WorkoutStore()
        let active = store.programs.filter { $0.isActive }
        XCTAssertEqual(active.count, 1, "Exactly one program must be active at a time")
        XCTAssertNotNil(store.activeProgram)
    }

    func testSetActiveProgramIsExclusive() throws {
        let store = WorkoutStore()
        guard store.programs.count >= 2 else {
            throw XCTSkip("Need at least two seeded programs")
        }
        let target = store.programs[1]
        store.setActiveProgram(target)
        XCTAssertEqual(store.programs.filter { $0.isActive }.count, 1)
        XCTAssertEqual(store.activeProgram?.id, target.id)
    }

    func testIsPRTrueWhenNoRecordExists() {
        let store = WorkoutStore()
        // An exercise name unlikely to exist in persisted records.
        let unique = "ZZ_TestLift_\(UUID().uuidString)"
        XCTAssertTrue(store.isPR(exerciseName: unique, estimated1RM: 50))
    }

    func testStartAndDiscardEmptyWorkout() {
        let store = WorkoutStore()
        _ = store.startEmptyWorkout(name: "Quick", type: .fullBody)
        XCTAssertTrue(store.isInWorkout)
        XCTAssertNotNil(store.currentSession)
        store.discardCurrentWorkout()
        XCTAssertFalse(store.isInWorkout)
        XCTAssertNil(store.currentSession)
    }

    func testStartProgramWorkoutPrePopulates() throws {
        let store = WorkoutStore()
        guard store.activeProgram?.nextWorkout != nil else {
            throw XCTSkip("Active program has no next workout")
        }
        let session = store.startProgramWorkout()
        XCTAssertNotNil(session)
        XCTAssertFalse(session?.exercises.isEmpty ?? true, "Program workout should bring exercises")
        store.discardCurrentWorkout()
    }

    func testNextWorkoutAdvancesCyclically() {
        var program = TrainingProgram(name: "AB", workouts: [
            ProgramWorkout(name: "A", label: "A", type: .upper),
            ProgramWorkout(name: "B", label: "B", type: .lower),
        ])
        XCTAssertEqual(program.nextWorkout?.label, "A")
        program.advance()
        XCTAssertEqual(program.nextWorkout?.label, "B")
        program.advance()
        XCTAssertEqual(program.nextWorkout?.label, "A", "Should wrap back to the first workout")
    }
}
