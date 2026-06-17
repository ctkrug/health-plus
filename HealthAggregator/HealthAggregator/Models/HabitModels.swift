import Foundation

// MARK: - Enums

enum HabitCategory: String, Codable, CaseIterable {
    case supplements  = "Supplements"
    case skincareAM   = "AM Skincare"
    case skincareMP   = "PM Skincare"
    case dental       = "Dental"
    case hydration    = "Hydration"
    case wellness     = "Wellness"
    case custom       = "Custom"

    var icon: String {
        switch self {
        case .supplements: return "pills.fill"
        case .skincareAM:  return "sun.max.fill"
        case .skincareMP:  return "moon.stars.fill"
        case .dental:      return "mouth.fill"
        case .hydration:   return "drop.fill"
        case .wellness:    return "heart.fill"
        case .custom:      return "checkmark.circle.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .supplements: return "#A855F7"
        case .skincareAM:  return "#F97316"
        case .skincareMP:  return "#3B82F6"
        case .dental:      return "#22C55E"
        case .hydration:   return "#14B8A6"
        case .wellness:    return "#EC4899"
        case .custom:      return "#6366F1"
        }
    }
}

enum HabitTimeSlot: String, Codable, CaseIterable {
    case am      = "AM"
    case pm      = "PM"
    case anytime = "Anytime"
}

// MARK: - Habit

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var category: HabitCategory
    var icon: String
    var colorHex: String
    var timeSlot: HabitTimeSlot = .anytime
    var isEnabled: Bool = true
    var orderIndex: Int = 0
    var routineGroup: String? = nil   // groups steps of same routine (e.g. "AM Skincare")
    var notes: String = ""

    static func == (lhs: Habit, rhs: Habit) -> Bool { lhs.id == rhs.id }
}

// MARK: - HabitLog

struct HabitLog: Identifiable, Codable {
    var id: UUID = UUID()
    var habitId: UUID
    var dayKey: String       // "yyyy-MM-dd"
    var timeSlot: HabitTimeSlot
    var completedAt: Date
}

// MARK: - Computed helpers

extension Habit {
    var categoryColor: String { colorHex }
}

extension HabitLog {
    // Static formatter: POSIX locale prevents non-Gregorian calendar systems
    // from producing non-comparable strings; timeZone is explicit for DST safety
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    static func dayKey(for date: Date) -> String {
        keyFormatter.string(from: date)
    }
}

// MARK: - Chat message model for setup flow

struct ChatMessage: Identifiable {
    var id: UUID = UUID()
    var role: Role
    var content: String
    var isLoading: Bool = false

    enum Role { case user, assistant }
}
