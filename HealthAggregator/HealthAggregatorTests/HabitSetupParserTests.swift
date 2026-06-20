import XCTest
@testable import HealthAggregator

/// REGRESSION: the AI habit coach once dumped its raw JSON into the chat instead of creating habits,
/// because the parser only recognized a literal ```json fence. These tests lock in tolerant parsing
/// across the formats the model actually produces, and guarantee no raw blob ever reaches the user.
final class HabitSetupParserTests: XCTestCase {

    private let payload = """
    {"habits":[
      {"name":"Vitamin D","category":"supplements","icon":"pills.fill","colorHex":"#A855F7","timeSlot":"am"},
      {"name":"Meditate","category":"mindfulness","timeSlot":"anytime"}
    ]}
    """

    func testParsesJsonFence() {
        let reply = "Here you go!\n```json\n\(payload)\n```"
        let habits = HabitSetupParser.parseHabits(from: reply)
        XCTAssertEqual(habits?.count, 2)
        XCTAssertEqual(habits?.first?.name, "Vitamin D")
        XCTAssertEqual(habits?.first?.category, .supplements)
    }

    func testParsesPlainFenceWithoutLanguage() {
        let reply = "All set:\n```\n\(payload)\n```"
        XCTAssertEqual(HabitSetupParser.parseHabits(from: reply)?.count, 2)
    }

    func testParsesBareJsonNoFence() {
        // The exact failure that shipped: model returns JSON with no code fence at all.
        let reply = "Great, I've got everything. \(payload)"
        XCTAssertEqual(HabitSetupParser.parseHabits(from: reply)?.count, 2)
    }

    func testParsesUppercaseJsonLabel() {
        let reply = "```JSON\n\(payload)\n```"
        XCTAssertEqual(HabitSetupParser.parseHabits(from: reply)?.count, 2)
    }

    func testDefaultsMissingFieldsFromCategory() {
        let reply = "```json\n{\"habits\":[{\"name\":\"Floss\",\"category\":\"dental\"}]}\n```"
        let h = HabitSetupParser.parseHabits(from: reply)?.first
        XCTAssertEqual(h?.icon, HabitCategory.dental.icon)
        XCTAssertEqual(h?.colorHex, HabitCategory.dental.colorHex)
    }

    func testUnknownCategoryFallsBackToCustom() {
        let reply = "{\"habits\":[{\"name\":\"Weird\",\"category\":\"zzz\"}]}"
        XCTAssertEqual(HabitSetupParser.parseHabits(from: reply)?.first?.category, .custom)
    }

    func testConversationalReplyReturnsNil() {
        let reply = "What supplements do you take each morning?"
        XCTAssertNil(HabitSetupParser.parseHabits(from: reply))
    }

    func testEmptyHabitsArrayReturnsNil() {
        XCTAssertNil(HabitSetupParser.parseHabits(from: "```json\n{\"habits\":[]}\n```"))
    }

    func testNamelessEntriesAreDropped() {
        let reply = "{\"habits\":[{\"category\":\"sleep\"},{\"name\":\"Sleep by 11\",\"category\":\"sleep\"}]}"
        XCTAssertEqual(HabitSetupParser.parseHabits(from: reply)?.count, 1)
    }

    // MARK: - sanitizedReply never leaks raw JSON

    func testSanitizeStripsFencedBlock() {
        let reply = "Here's your setup:\n```json\n\(payload)\n```\nEnjoy!"
        let s = HabitSetupParser.sanitizedReply(reply)
        XCTAssertFalse(s.contains("```"))
        XCTAssertFalse(s.contains("\"habits\""))
        XCTAssertTrue(s.contains("Enjoy"))
    }

    func testSanitizeReplacesBareJsonWithFriendlyMessage() {
        let s = HabitSetupParser.sanitizedReply(payload)
        XCTAssertFalse(s.contains("\"habits\""))
        XCTAssertFalse(s.hasPrefix("{"))
    }

    func testSanitizeKeepsNormalProse() {
        let s = HabitSetupParser.sanitizedReply("Which supplements do you take?")
        XCTAssertEqual(s, "Which supplements do you take?")
    }

    // MARK: - category mapping covers the new categories

    func testCategoryMappingCoversNewCategories() {
        XCTAssertEqual(HabitSetupParser.categoryFromString("morning"), .morning)
        XCTAssertEqual(HabitSetupParser.categoryFromString("fitness"), .fitness)
        XCTAssertEqual(HabitSetupParser.categoryFromString("Nutrition"), .nutrition)
        XCTAssertEqual(HabitSetupParser.categoryFromString("skincare_pm"), .skincareMP)
    }
}
