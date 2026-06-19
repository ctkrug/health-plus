import XCTest
@testable import HealthAggregator

/// HabitStore mixes completion logging, streaks, milestones, and all-time counts. These tests
/// run against a cleared UserDefaults so they don't depend on (or pollute) real app state.
final class HabitStoreTests: XCTestCase {

    private let keys = ["saved_habits", "saved_habit_logs", "habit_all_time_counts",
                        "habit_shown_milestones", "habitSetupComplete"]

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - Toggle + completion

    func testToggleAddsAndRemovesCompletion() {
        let store = HabitStore()
        let habit = Fixture.habit("Water")
        store.addHabit(habit)

        XCTAssertFalse(store.isCompleted(habit, slot: .anytime))
        store.toggle(habit, slot: .anytime)
        XCTAssertTrue(store.isCompleted(habit, slot: .anytime))
        store.toggle(habit, slot: .anytime)
        XCTAssertFalse(store.isCompleted(habit, slot: .anytime))
    }

    func testTotalCompletionsIncrementsAndDecrements() {
        let store = HabitStore()
        let habit = Fixture.habit("Vitamin D")
        store.addHabit(habit)

        store.toggle(habit, slot: .anytime)
        XCTAssertEqual(store.totalCompletions(for: habit), 1)
        store.toggle(habit, slot: .anytime)  // undo
        XCTAssertEqual(store.totalCompletions(for: habit), 0)
    }

    // MARK: - Milestones

    func testFirstCompletionFiresMilestone() {
        let store = HabitStore()
        let habit = Fixture.habit("Meditate")
        store.addHabit(habit)

        XCTAssertNil(store.pendingMilestone)
        store.toggle(habit, slot: .anytime)
        XCTAssertEqual(store.pendingMilestone?.count, 1)
        XCTAssertEqual(store.pendingMilestone?.habit.id, habit.id)
    }

    func testMilestoneNotRefiredAfterUndoAndRedoSameDay() {
        let store = HabitStore()
        let habit = Fixture.habit("Floss")
        store.addHabit(habit)

        store.toggle(habit, slot: .anytime)   // count → 1, milestone fires
        store.pendingMilestone = nil
        store.toggle(habit, slot: .anytime)   // undo → count 0
        store.toggle(habit, slot: .anytime)   // redo → count 1 again
        // The "1" milestone was already shown, so it must not fire a second time.
        XCTAssertNil(store.pendingMilestone)
    }

    // MARK: - Streaks (drive via logs directly across multiple days)

    func testStreakCountsConsecutiveDays() {
        let store = HabitStore()
        let habit = Fixture.habit("Run")
        store.addHabit(habit)

        let cal = Calendar.current
        // today, yesterday, 2 days ago
        store.logs = (0...2).map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            return HabitLog(habitId: habit.id, dayKey: HabitLog.dayKey(for: day),
                            timeSlot: .anytime, completedAt: day)
        }
        XCTAssertEqual(store.streak(for: habit, slot: .anytime), 3)
    }

    func testStreakBreaksOnGap() {
        let store = HabitStore()
        let habit = Fixture.habit("Run")
        store.addHabit(habit)

        let cal = Calendar.current
        // today and 3 days ago (gap at day 1 and 2) → streak should be just today (1)
        store.logs = [0, 3].map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            return HabitLog(habitId: habit.id, dayKey: HabitLog.dayKey(for: day),
                            timeSlot: .anytime, completedAt: day)
        }
        XCTAssertEqual(store.streak(for: habit, slot: .anytime), 1)
    }

    func testStreakSurvivesMissingToday() {
        let store = HabitStore()
        let habit = Fixture.habit("Run")
        store.addHabit(habit)

        let cal = Calendar.current
        // yesterday and 2 days ago, but not today → streak 2 (anchor allowed at yesterday)
        store.logs = [1, 2].map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            return HabitLog(habitId: habit.id, dayKey: HabitLog.dayKey(for: day),
                            timeSlot: .anytime, completedAt: day)
        }
        XCTAssertEqual(store.streak(for: habit, slot: .anytime), 2)
    }

    // MARK: - CRUD

    func testDeleteHabitRemovesLogsAndCounts() {
        let store = HabitStore()
        let habit = Fixture.habit("Stretch")
        store.addHabit(habit)
        store.toggle(habit, slot: .anytime)

        store.deleteHabit(habit)
        XCTAssertFalse(store.habits.contains { $0.id == habit.id })
        XCTAssertEqual(store.totalCompletions(for: habit), 0)
        XCTAssertTrue(store.logs.allSatisfy { $0.habitId != habit.id })
    }

    func testUpdateHabitPersistsChanges() {
        let store = HabitStore()
        var habit = Fixture.habit("Read", category: .mindfulness)
        store.addHabit(habit)

        habit.name = "Read 30 min"
        habit.colorHex = "#123456"
        store.updateHabit(habit)

        let updated = store.habits.first { $0.id == habit.id }
        XCTAssertEqual(updated?.name, "Read 30 min")
        XCTAssertEqual(updated?.colorHex, "#123456")
    }

    func testAddHabitMarksSetupComplete() {
        let store = HabitStore()
        XCTAssertFalse(store.isSetupComplete)
        store.addHabit(Fixture.habit())
        XCTAssertTrue(store.isSetupComplete)
    }

    func testTodayProgressCounts() {
        let store = HabitStore()
        let a = Fixture.habit("A"); let b = Fixture.habit("B")
        store.addHabit(a); store.addHabit(b)
        XCTAssertEqual(store.todayTotal, 2)
        XCTAssertEqual(store.todayCompleted, 0)
        store.toggle(a, slot: .anytime)
        XCTAssertEqual(store.todayCompleted, 1)
        XCTAssertEqual(store.todayFraction, 0.5, accuracy: 0.001)
    }

    // MARK: - dayKey format

    func testDayKeyFormatIsZeroPaddedISO() {
        let comps = DateComponents(year: 2026, month: 3, day: 5)
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(HabitLog.dayKey(for: date), "2026-03-05")
    }
}
