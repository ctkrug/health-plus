import Foundation

// MARK: - Enums

enum HabitCategory: String, Codable, CaseIterable {
    // Existing (raw values preserved for backward compat)
    case supplements  = "Supplements"
    case skincareAM   = "AM Skincare"
    case skincareMP   = "PM Skincare"
    case dental       = "Dental"
    case hydration    = "Hydration"
    case wellness     = "Wellness"
    case custom       = "Custom"
    // New
    case morning      = "Morning"
    case evening      = "Evening"
    case fitness      = "Fitness"
    case mindfulness  = "Mindfulness"
    case nutrition    = "Nutrition"
    case sleep        = "Sleep"

    var icon: String {
        switch self {
        case .supplements: return "pills.fill"
        case .skincareAM:  return "sun.max.fill"
        case .skincareMP:  return "moon.stars.fill"
        case .dental:      return "mouth.fill"
        case .hydration:   return "drop.fill"
        case .wellness:    return "heart.fill"
        case .custom:      return "checkmark.circle.fill"
        case .morning:     return "sunrise.fill"
        case .evening:     return "moon.fill"
        case .fitness:     return "dumbbell.fill"
        case .mindfulness: return "brain.head.profile"
        case .nutrition:   return "fork.knife"
        case .sleep:       return "bed.double.fill"
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
        case .morning:     return "#F59E0B"
        case .evening:     return "#8B5CF6"
        case .fitness:     return "#EF4444"
        case .mindfulness: return "#06B6D4"
        case .nutrition:   return "#84CC16"
        case .sleep:       return "#6366F1"
        }
    }

    static var libraryOrder: [HabitCategory] {
        [.morning, .supplements, .fitness, .hydration, .mindfulness,
         .nutrition, .sleep, .evening, .skincareAM, .skincareMP, .dental, .wellness]
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
    var routineGroup: String? = nil
    var notes: String = ""

    static func == (lhs: Habit, rhs: Habit) -> Bool { lhs.id == rhs.id }
}

// MARK: - HabitLog

struct HabitLog: Identifiable, Codable {
    var id: UUID = UUID()
    var habitId: UUID
    var dayKey: String
    var timeSlot: HabitTimeSlot
    var completedAt: Date
}

// MARK: - Milestone Event

struct HabitMilestoneEvent: Equatable {
    let habit: Habit
    let count: Int
}

// MARK: - Milestone definitions

enum HabitMilestone {
    static let counts = [1, 10, 25, 50, 100, 200, 365, 500]

    static func title(for count: Int) -> String {
        switch count {
        case 1:   return "First Time!"
        case 10:  return "10 Times!"
        case 25:  return "25 Down!"
        case 50:  return "50 Times!"
        case 100: return "100 Times!"
        case 200: return "200 Times!"
        case 365: return "365 Times!"
        case 500: return "500 Times!"
        default:  return "\(count) Completions!"
        }
    }

    static func message(for count: Int) -> String {
        switch count {
        case 1:   return "Every legend starts somewhere.\nYou started today."
        case 10:  return "10 reps in.\nBuilding real momentum now."
        case 25:  return "25 completions.\nThe habit is taking root."
        case 50:  return "Halfway to 100.\nConsistency is your superpower."
        case 100: return "100 times.\nThis is who you are now."
        case 200: return "200 completions.\nYou've earned that streak."
        case 365: return "A full year's worth.\nAbsolute legend."
        case 500: return "500 times.\nThere's no turning back."
        default:  return "Keep going — every rep counts."
        }
    }

    static func emoji(for count: Int) -> String {
        switch count {
        case 1:   return "🎉"
        case 10:  return "💪"
        case 25:  return "🔥"
        case 50:  return "⚡️"
        case 100: return "🏆"
        case 200: return "👑"
        case 365: return "🌟"
        case 500: return "🦾"
        default:  return "✅"
        }
    }
}

// MARK: - Preset Library

struct PresetHabit: Identifiable {
    let id = UUID()
    let name: String
    let category: HabitCategory
    let icon: String
    let timeSlot: HabitTimeSlot

    var colorHex: String { category.colorHex }

    func toHabit() -> Habit {
        Habit(name: name, category: category, icon: icon, colorHex: colorHex, timeSlot: timeSlot)
    }
}

enum HabitLibrary {
    static let presets: [PresetHabit] = [
        // MORNING
        PresetHabit(name: "Morning Sunlight",       category: .morning,     icon: "sun.max.fill",           timeSlot: .am),
        PresetHabit(name: "Cold Shower",            category: .morning,     icon: "shower.fill",            timeSlot: .am),
        PresetHabit(name: "Meditate",               category: .morning,     icon: "brain.head.profile",     timeSlot: .am),
        PresetHabit(name: "Journal",                category: .morning,     icon: "book.fill",              timeSlot: .am),
        PresetHabit(name: "Breathwork",             category: .morning,     icon: "wind",                   timeSlot: .am),
        PresetHabit(name: "Morning Walk",           category: .morning,     icon: "figure.walk",            timeSlot: .am),
        PresetHabit(name: "Stretch",                category: .morning,     icon: "figure.flexibility",     timeSlot: .am),
        PresetHabit(name: "Make Bed",               category: .morning,     icon: "bed.double.fill",        timeSlot: .am),
        PresetHabit(name: "No Phone First 30 Min",  category: .morning,     icon: "iphone.slash",           timeSlot: .am),
        PresetHabit(name: "Weigh Myself",           category: .morning,     icon: "scalemass.fill",         timeSlot: .am),
        PresetHabit(name: "Cold Plunge",            category: .morning,     icon: "thermometer.snowflake",  timeSlot: .am),

        // SUPPLEMENTS
        PresetHabit(name: "Vitamin D3 + K2",        category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "Omega-3 Fish Oil",       category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "Magnesium Glycinate",    category: .supplements, icon: "pills.fill",             timeSlot: .pm),
        PresetHabit(name: "Zinc",                   category: .supplements, icon: "pills.fill",             timeSlot: .anytime),
        PresetHabit(name: "Creatine",               category: .supplements, icon: "pills.fill",             timeSlot: .anytime),
        PresetHabit(name: "Collagen Peptides",      category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "Probiotics",             category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "Ashwagandha",            category: .supplements, icon: "leaf.fill",              timeSlot: .pm),
        PresetHabit(name: "NAC",                    category: .supplements, icon: "pills.fill",             timeSlot: .anytime),
        PresetHabit(name: "Protein Shake",          category: .supplements, icon: "cup.and.saucer.fill",   timeSlot: .anytime),
        PresetHabit(name: "Electrolytes",           category: .supplements, icon: "drop.fill",              timeSlot: .anytime),
        PresetHabit(name: "Vitamin C",              category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "B-Complex",              category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "L-Theanine",             category: .supplements, icon: "pills.fill",             timeSlot: .anytime),
        PresetHabit(name: "Berberine",              category: .supplements, icon: "pills.fill",             timeSlot: .anytime),
        PresetHabit(name: "CoQ10",                  category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "Turmeric / Curcumin",    category: .supplements, icon: "pills.fill",             timeSlot: .anytime),
        PresetHabit(name: "Alpha-GPC",              category: .supplements, icon: "pills.fill",             timeSlot: .am),
        PresetHabit(name: "NMN / NR",               category: .supplements, icon: "pills.fill",             timeSlot: .am),

        // FITNESS
        PresetHabit(name: "Workout",                category: .fitness,     icon: "dumbbell.fill",          timeSlot: .anytime),
        PresetHabit(name: "10K Steps",              category: .fitness,     icon: "figure.walk",            timeSlot: .anytime),
        PresetHabit(name: "Zone 2 Cardio",          category: .fitness,     icon: "heart.circle.fill",      timeSlot: .anytime),
        PresetHabit(name: "Mobility Work",          category: .fitness,     icon: "figure.flexibility",     timeSlot: .anytime),
        PresetHabit(name: "Cold Plunge",            category: .fitness,     icon: "thermometer.snowflake",  timeSlot: .anytime),
        PresetHabit(name: "Sauna",                  category: .fitness,     icon: "thermometer.sun.fill",   timeSlot: .anytime),
        PresetHabit(name: "Swim",                   category: .fitness,     icon: "figure.pool.swim",       timeSlot: .anytime),

        // HYDRATION
        PresetHabit(name: "Morning Water (500ml)",  category: .hydration,   icon: "drop.fill",              timeSlot: .am),
        PresetHabit(name: "3L Water Goal",          category: .hydration,   icon: "drop.fill",              timeSlot: .anytime),
        PresetHabit(name: "Green Tea",              category: .hydration,   icon: "cup.and.saucer.fill",   timeSlot: .anytime),
        PresetHabit(name: "No Alcohol",             category: .hydration,   icon: "xmark.circle.fill",      timeSlot: .anytime),
        PresetHabit(name: "Limit Caffeine",         category: .hydration,   icon: "cup.and.saucer.fill",   timeSlot: .anytime),

        // MINDFULNESS
        PresetHabit(name: "Meditate (10 min)",      category: .mindfulness, icon: "brain.head.profile",     timeSlot: .anytime),
        PresetHabit(name: "Gratitude Journal",      category: .mindfulness, icon: "heart.fill",             timeSlot: .pm),
        PresetHabit(name: "Read (30 min)",          category: .mindfulness, icon: "book.fill",              timeSlot: .pm),
        PresetHabit(name: "No Social Media",        category: .mindfulness, icon: "iphone.slash",           timeSlot: .anytime),
        PresetHabit(name: "Breathwork",             category: .mindfulness, icon: "wind",                   timeSlot: .anytime),
        PresetHabit(name: "Daily Walk",             category: .mindfulness, icon: "figure.walk",            timeSlot: .anytime),

        // NUTRITION
        PresetHabit(name: "Hit Protein Goal",       category: .nutrition,   icon: "fork.knife",             timeSlot: .anytime),
        PresetHabit(name: "Track Calories",         category: .nutrition,   icon: "chart.bar.fill",         timeSlot: .anytime),
        PresetHabit(name: "Eat Vegetables",         category: .nutrition,   icon: "leaf.fill",              timeSlot: .anytime),
        PresetHabit(name: "No Junk Food",           category: .nutrition,   icon: "xmark.circle.fill",      timeSlot: .anytime),
        PresetHabit(name: "Limit Sugar",            category: .nutrition,   icon: "xmark.circle.fill",      timeSlot: .anytime),
        PresetHabit(name: "Intermittent Fasting",   category: .nutrition,   icon: "timer",                  timeSlot: .anytime),

        // SLEEP
        PresetHabit(name: "Sleep by 10:30pm",       category: .sleep,       icon: "bed.double.fill",        timeSlot: .pm),
        PresetHabit(name: "8 Hours Target",         category: .sleep,       icon: "moon.fill",              timeSlot: .pm),
        PresetHabit(name: "No Screens 1hr Before",  category: .sleep,       icon: "iphone.slash",           timeSlot: .pm),
        PresetHabit(name: "Consistent Wake Time",   category: .sleep,       icon: "alarm.fill",             timeSlot: .am),
        PresetHabit(name: "Blue Light Glasses",     category: .sleep,       icon: "eyeglasses",             timeSlot: .pm),
        PresetHabit(name: "Sleep Tracking",         category: .sleep,       icon: "waveform",               timeSlot: .pm),

        // EVENING
        PresetHabit(name: "Evening Walk",           category: .evening,     icon: "figure.walk",            timeSlot: .pm),
        PresetHabit(name: "Read",                   category: .evening,     icon: "book.fill",              timeSlot: .pm),
        PresetHabit(name: "Gratitude List",         category: .evening,     icon: "list.bullet",            timeSlot: .pm),
        PresetHabit(name: "Wind-Down Stretch",      category: .evening,     icon: "figure.flexibility",     timeSlot: .pm),
        PresetHabit(name: "Plan Tomorrow",          category: .evening,     icon: "calendar",               timeSlot: .pm),
        PresetHabit(name: "No Screens After 9pm",   category: .evening,     icon: "iphone.slash",           timeSlot: .pm),

        // AM SKINCARE
        PresetHabit(name: "Cleanser",               category: .skincareAM,  icon: "drop.fill",              timeSlot: .am),
        PresetHabit(name: "Vitamin C Serum",        category: .skincareAM,  icon: "drop.fill",              timeSlot: .am),
        PresetHabit(name: "Moisturizer",            category: .skincareAM,  icon: "drop.fill",              timeSlot: .am),
        PresetHabit(name: "Sunscreen SPF 50",       category: .skincareAM,  icon: "sun.max.fill",           timeSlot: .am),
        PresetHabit(name: "Eye Cream",              category: .skincareAM,  icon: "eye.fill",               timeSlot: .am),
        PresetHabit(name: "Toner",                  category: .skincareAM,  icon: "drop.fill",              timeSlot: .am),

        // PM SKINCARE
        PresetHabit(name: "Face Wash",              category: .skincareMP,  icon: "drop.fill",              timeSlot: .pm),
        PresetHabit(name: "Retinol",                category: .skincareMP,  icon: "drop.fill",              timeSlot: .pm),
        PresetHabit(name: "Night Moisturizer",      category: .skincareMP,  icon: "drop.fill",              timeSlot: .pm),
        PresetHabit(name: "Niacinamide",            category: .skincareMP,  icon: "drop.fill",              timeSlot: .pm),

        // DENTAL
        PresetHabit(name: "Floss",                  category: .dental,      icon: "mouth.fill",             timeSlot: .pm),
        PresetHabit(name: "Mouthwash",              category: .dental,      icon: "mouth.fill",             timeSlot: .pm),
        PresetHabit(name: "Tongue Scraper",         category: .dental,      icon: "mouth.fill",             timeSlot: .am),
        PresetHabit(name: "Oil Pulling",            category: .dental,      icon: "drop.fill",              timeSlot: .am),
        PresetHabit(name: "Water Flosser",          category: .dental,      icon: "drop.fill",              timeSlot: .pm),

        // WELLNESS
        PresetHabit(name: "No Alcohol Today",       category: .wellness,    icon: "xmark.circle.fill",      timeSlot: .anytime),
        PresetHabit(name: "Sunlight 20 min",        category: .wellness,    icon: "sun.max.fill",           timeSlot: .anytime),
        PresetHabit(name: "Social Connection",      category: .wellness,    icon: "person.2.fill",          timeSlot: .anytime),
        PresetHabit(name: "Limit Screen Time",      category: .wellness,    icon: "iphone.slash",           timeSlot: .anytime),
    ]

    static func presets(for category: HabitCategory) -> [PresetHabit] {
        presets.filter { $0.category == category }
    }
}

// MARK: - Computed helpers

extension Habit {
    var categoryColor: String { colorHex }
}

extension HabitLog {
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
