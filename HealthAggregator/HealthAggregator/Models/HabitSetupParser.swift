import Foundation

/// Parses the AI habit-coach reply into habits. Extracted from the chat view so it can be unit
/// tested — the model doesn't always wrap its JSON exactly as asked (```json vs ``` vs no fence vs
/// surrounding prose), and a parse miss must NEVER dump a raw JSON blob into the chat.
enum HabitSetupParser {

    /// Build habits from a model reply, or nil if it isn't a (valid, non-empty) habits payload.
    /// Legacy text path (tolerant fenced/bare-JSON extraction) — kept as a fallback. The primary
    /// path is now `buildHabits(from:)` fed by a forced tool call (guaranteed-valid structure).
    static func parseHabits(from text: String) -> [Habit]? {
        guard let json = extractHabitsJSON(from: text) else { return nil }
        return buildHabits(from: json)
    }

    /// Build habits from an already-parsed JSON object — e.g. a tool_use `input` from `runTool`.
    /// Returns nil for an empty/invalid payload. This is the reliable path: the structure is
    /// constrained by the tool's input schema, so there's no prose to strip or fence to find.
    static func buildHabits(from json: [String: Any]) -> [Habit]? {
        guard let habitsArr = json["habits"] as? [[String: Any]] else { return nil }
        let habits = habitsArr.compactMap { dict -> Habit? in
            guard let name = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return nil }
            let category = categoryFromString((dict["category"] as? String) ?? "custom")
            let icon = dict["icon"] as? String ?? category.icon
            let colorHex = dict["colorHex"] as? String ?? category.colorHex
            let slotStr = (dict["timeSlot"] as? String ?? "anytime").lowercased()
            let slot: HabitTimeSlot = slotStr == "am" ? .am : slotStr == "pm" ? .pm : .anytime
            let group = dict["routineGroup"] as? String
            return Habit(name: name, category: category, icon: icon, colorHex: colorHex,
                         timeSlot: slot, routineGroup: group)
        }
        return habits.isEmpty ? nil : habits
    }

    // MARK: - Extraction tool (forced tool use)

    /// Valid category strings, mirrored from `categoryFromString` — kept here so the tool schema's
    /// enum can constrain the model to categories the app actually understands.
    static let categoryValues = [
        "morning", "evening", "fitness", "mindfulness", "nutrition", "sleep",
        "supplements", "skincareAM", "skincareMP", "dental", "hydration", "wellness", "custom",
    ]

    static let toolName = "save_habits"

    static let toolDescription = """
    Save the full set of daily wellness habits the user wants to track, extracted from the \
    conversation. Call this exactly once with every habit they mentioned (supplements, routines, \
    fitness, mindfulness, nutrition, skincare, dental, hydration, sleep, etc.). Infer a sensible \
    category, SF Symbol icon, and hex color for each. Do not invent habits the user didn't mention.
    """

    /// JSON Schema for the `save_habits` tool input. Built as a dictionary so it can be passed
    /// straight to `JSONSerialization` in the request body.
    static var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "habits": [
                    "type": "array",
                    "description": "Every habit the user wants to track.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Short habit name, e.g. \"Vitamin D\" or \"Morning Meditation\"."],
                            "category": ["type": "string", "enum": categoryValues],
                            "icon": ["type": "string", "description": "An SF Symbol name, e.g. pills.fill, drop.fill, figure.run, moon.stars.fill."],
                            "colorHex": ["type": "string", "description": "Hex color matching the category feel, e.g. #A855F7."],
                            "timeSlot": ["type": "string", "enum": ["am", "pm", "anytime"]],
                            "routineGroup": ["type": "string", "description": "Optional group label, e.g. \"AM Skincare\"."],
                        ],
                        "required": ["name", "category"],
                    ],
                ],
            ],
            "required": ["habits"],
        ]
    }

    /// Robustly pull the habits JSON object out of a reply: tolerates ```json fences, plain ```
    /// fences, no fence, or surrounding prose.
    static func extractHabitsJSON(from text: String) -> [String: Any]? {
        for candidate in [firstFencedBlock(text), bracesBlock(text)].compactMap({ $0 }) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = trimmed.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               obj["habits"] != nil {
                return obj
            }
        }
        return nil
    }

    /// Strip any fenced code/JSON block so a parse-failure never shows the user a raw blob.
    static func sanitizedReply(_ reply: String) -> String {
        var s = reply
        while let open = s.range(of: "```"),
              let close = s.range(of: "```", range: open.upperBound..<s.endIndex) {
            s.removeSubrange(open.lowerBound..<close.upperBound)
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || s.contains("\"habits\"") || (s.hasPrefix("{") && s.hasSuffix("}")) {
            return "Got it! Tell me any other habits you'd like, or say \"that's everything\" and I'll finish setting them up."
        }
        return s
    }

    static func categoryFromString(_ s: String) -> HabitCategory {
        switch s.lowercased() {
        case "morning":                                                return .morning
        case "evening":                                                return .evening
        case "fitness":                                                return .fitness
        case "mindfulness":                                            return .mindfulness
        case "nutrition":                                              return .nutrition
        case "sleep":                                                  return .sleep
        case "supplements":                                            return .supplements
        case "skincaream", "skincare_am", "am skincare", "am_skincare": return .skincareAM
        case "skincarepm", "skincaremp", "skincare_pm", "skincare_mp", "pm skincare", "pm_skincare": return .skincareMP
        case "dental":                                                 return .dental
        case "hydration":                                              return .hydration
        case "wellness":                                               return .wellness
        default:                                                       return .custom
        }
    }

    // MARK: - JSON block extraction

    /// Contents of the first ``` … ``` block, skipping an optional language label (e.g. "json").
    private static func firstFencedBlock(_ text: String) -> String? {
        guard let open = text.range(of: "```") else { return nil }
        var start = open.upperBound
        if let nl = text[start...].firstIndex(of: "\n") {
            let label = text[start..<nl].trimmingCharacters(in: .whitespaces)
            if !label.contains("{") { start = text.index(after: nl) }   // drop the "json" label line
        }
        guard let close = text.range(of: "```", range: start..<text.endIndex) else {
            return String(text[start...])   // no closing fence — take the remainder
        }
        return String(text[start..<close.lowerBound])
    }

    /// Everything from the first "{" to the last "}" — catches bare/unfenced JSON.
    private static func bracesBlock(_ text: String) -> String? {
        guard let lo = text.firstIndex(of: "{"),
              let hi = text.lastIndex(of: "}"), lo < hi else { return nil }
        return String(text[lo...hi])
    }
}
