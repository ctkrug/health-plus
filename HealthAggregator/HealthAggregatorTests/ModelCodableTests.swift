import XCTest
@testable import HealthAggregator

/// Persistence is JSON-based (UserDefaults + Core Data blobs). A broken Codable conformance would
/// silently drop user data on the next launch, so we round-trip every persisted model.
final class ModelCodableTests: XCTestCase {

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testHabitRoundTripPreservesAllFields() throws {
        let habit = Habit(name: "Retinol", category: .skincareMP, icon: "drop.fill",
                          colorHex: "#8B5CF6", timeSlot: .pm, isEnabled: true,
                          orderIndex: 3, routineGroup: "PM Skincare", notes: "every other night")
        let out = try roundTrip(habit)
        XCTAssertEqual(out.id, habit.id)
        XCTAssertEqual(out.name, habit.name)
        XCTAssertEqual(out.category, habit.category)
        XCTAssertEqual(out.icon, habit.icon)
        XCTAssertEqual(out.colorHex, habit.colorHex)
        XCTAssertEqual(out.timeSlot, habit.timeSlot)
        XCTAssertEqual(out.routineGroup, habit.routineGroup)
        XCTAssertEqual(out.notes, habit.notes)
    }

    func testHabitLogRoundTrip() throws {
        let log = HabitLog(habitId: UUID(), dayKey: "2026-06-19", timeSlot: .am, completedAt: Date())
        let out = try roundTrip(log)
        XCTAssertEqual(out.habitId, log.habitId)
        XCTAssertEqual(out.dayKey, log.dayKey)
        XCTAssertEqual(out.timeSlot, log.timeSlot)
    }

    func testWorkoutSessionRoundTrip() throws {
        var session = WorkoutSession(name: "Push Day", type: .push, startDate: Date())
        session.endDate = Date().addingTimeInterval(3600)
        var ex = WorkoutExercise(name: "Bench Press", orderIndex: 0)
        ex.sets = [WorkoutSet(setNumber: 1, weightKg: 100, reps: 5, isCompleted: true, isPR: true)]
        session.exercises = [ex]
        session.totalVolumeKg = 500

        let out = try roundTrip(session)
        XCTAssertEqual(out.id, session.id)
        XCTAssertEqual(out.exercises.first?.name, "Bench Press")
        XCTAssertEqual(out.exercises.first?.sets.first?.weightKg, 100)
        XCTAssertTrue(out.exercises.first?.sets.first?.isPR ?? false)
    }

    func testWhoopSnapshotRoundTrip() throws {
        var snap = WhoopSnapshot()
        snap.recoveryScore = 66
        snap.hrv = 45
        snap.restingHR = 55
        snap.strain = 12.3
        snap.sleepPerformance = 88
        snap.lastUpdated = Date()
        let out = try roundTrip(snap)
        XCTAssertEqual(out.recoveryScore, 66)
        XCTAssertEqual(out.strain ?? 0, 12.3, accuracy: 0.001)
        XCTAssertTrue(out.isConnected)
    }

    func testTrainingProgramRoundTrip() throws {
        let pe = ProgramExercise(exerciseName: "Squat", equipment: .barbell, orderIndex: 0,
                                 rule: Fixture.rule(.linearWeight))
        let pw = ProgramWorkout(name: "Legs", label: "A", type: .legs, exercises: [pe])
        var program = TrainingProgram(name: "Starting Strength", workouts: [pw])
        program.isActive = true

        let out = try roundTrip(program)
        XCTAssertEqual(out.name, "Starting Strength")
        XCTAssertEqual(out.workouts.first?.exercises.first?.exerciseName, "Squat")
        XCTAssertTrue(out.isActive)
    }

    func testWorkoutTemplateRoundTrip() throws {
        let te = TemplateExercise(name: "Overhead Press", orderIndex: 0, defaultSets: 5, defaultReps: 5)
        let template = WorkoutTemplate(name: "Upper", type: .upper, exercises: [te])
        let out = try roundTrip(template)
        XCTAssertEqual(out.exercises.first?.defaultSets, 5)
        XCTAssertEqual(out.type, .upper)
    }

    // MARK: - Forward-compat: a habit with an unknown-to-old-code category still needs a valid raw value

    func testEveryHabitCategoryHasStableRawValue() throws {
        for cat in HabitCategory.allCases {
            let data = try JSONEncoder().encode(cat)
            let decoded = try JSONDecoder().decode(HabitCategory.self, from: data)
            XCTAssertEqual(decoded, cat)
        }
    }
}
