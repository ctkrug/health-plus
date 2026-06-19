import XCTest
@testable import HealthAggregator

/// Guards the preset library + habit category metadata. A bad hex string or empty icon would
/// render as a broken chip, and the AI-coach prompt relies on this metadata staying consistent.
final class HabitLibraryTests: XCTestCase {

    private let hexPattern = try! NSRegularExpression(pattern: "^#[0-9A-Fa-f]{6}$")

    private func isValidHex(_ s: String) -> Bool {
        hexPattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    func testLibraryHasManyPresets() {
        XCTAssertGreaterThanOrEqual(HabitLibrary.presets.count, 60, "Expected a deep preset library")
    }

    func testEveryPresetIsWellFormed() {
        for p in HabitLibrary.presets {
            XCTAssertFalse(p.name.trimmingCharacters(in: .whitespaces).isEmpty, "Empty preset name")
            XCTAssertFalse(p.icon.isEmpty, "Empty icon for \(p.name)")
            XCTAssertTrue(isValidHex(p.colorHex), "Bad hex \(p.colorHex) for \(p.name)")
        }
    }

    func testPresetsForCategoryAreFiltered() {
        let morning = HabitLibrary.presets(for: .morning)
        XCTAssertFalse(morning.isEmpty)
        XCTAssertTrue(morning.allSatisfy { $0.category == .morning })
    }

    func testEveryCategoryHasValidIconAndColor() {
        for cat in HabitCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "Empty icon for category \(cat)")
            XCTAssertTrue(isValidHex(cat.colorHex), "Bad hex for category \(cat)")
        }
    }

    func testLibraryOrderHasNoDuplicatesAndExcludesCustom() {
        let order = HabitCategory.libraryOrder
        XCTAssertEqual(Set(order).count, order.count, "Duplicate category in libraryOrder")
        XCTAssertFalse(order.contains(.custom), "Custom shouldn't be a browsable library category")
    }

    func testLibraryOrderCoversEveryNonCustomCategory() {
        let expected = Set(HabitCategory.allCases).subtracting([.custom])
        XCTAssertEqual(Set(HabitCategory.libraryOrder), expected,
                       "libraryOrder must list every non-custom category exactly once")
    }

    // MARK: - Milestones

    func testMilestoneCountsAreSortedAndUnique() {
        let counts = HabitMilestone.counts
        XCTAssertEqual(counts, counts.sorted(), "Milestone counts must be ascending")
        XCTAssertEqual(Set(counts).count, counts.count, "Milestone counts must be unique")
        XCTAssertEqual(counts.first, 1, "First completion is a milestone")
    }

    func testMilestoneCopyExistsForEveryCount() {
        for c in HabitMilestone.counts {
            XCTAssertFalse(HabitMilestone.title(for: c).isEmpty)
            XCTAssertFalse(HabitMilestone.message(for: c).isEmpty)
            XCTAssertFalse(HabitMilestone.emoji(for: c).isEmpty)
        }
    }

    // MARK: - PresetHabit → Habit conversion

    func testToHabitCarriesMetadata() {
        let preset = PresetHabit(name: "Creatine", category: .supplements, icon: "pills.fill", timeSlot: .anytime)
        let habit = preset.toHabit()
        XCTAssertEqual(habit.name, "Creatine")
        XCTAssertEqual(habit.category, .supplements)
        XCTAssertEqual(habit.icon, "pills.fill")
        XCTAssertEqual(habit.colorHex, HabitCategory.supplements.colorHex)
    }
}
