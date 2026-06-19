import SwiftUI
import HealthKit

// Types for the personalized insights engine.
// The science + sources behind every threshold are documented in docs/SCIENCE.md.

/// How a measured value compares to its science-based target.
enum MetricRating {
    case low            // below a healthy floor (e.g. body fat under essential, VO2 below average)
    case belowTarget    // under target but not unhealthy
    case healthy        // in the healthy/recommended band
    case strong         // better than average — athletic
    case elite          // top tier
    case elevated       // above a healthy ceiling (e.g. high body fat)
    case unknown        // not enough data

    var label: String {
        switch self {
        case .low:          return "Low"
        case .belowTarget:  return "Below Target"
        case .healthy:      return "Healthy"
        case .strong:       return "Athletic"
        case .elite:        return "Elite"
        case .elevated:     return "Elevated"
        case .unknown:      return "—"
        }
    }

    var color: Color {
        switch self {
        case .low, .elevated:   return .accentOrange
        case .belowTarget:      return .accentYellow
        case .healthy:          return .accentGreen
        case .strong:           return .accentBlue
        case .elite:            return .accentPurple
        case .unknown:          return .textTertiary
        }
    }
}

/// A single coaching insight surfaced in the UI.
struct MetricInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String          // e.g. "18.2%"
    let rating: MetricRating
    let target: String?        // e.g. "Target 10–17%"
    let detail: String         // one-sentence trainer-style explanation
}

/// Training recommendation derived from recovery state.
struct RecoveryGuidance {
    let headline: String       // e.g. "Primed to perform"
    let recommendation: String // what to do today
    let rating: MetricRating
    let icon: String
    let notes: [String]        // HRV / RHR context lines (may be empty)
}

/// Snapshot of everything the engine needs. Built from HealthKit + WHOOP + workout history.
struct UserMetrics {
    enum Sex { case male, female, unknown }

    var sex: Sex = .unknown
    var age: Int? = nil
    var weightKg: Double = 0
    var heightM: Double = 0
    var bodyFatFraction: Double = 0      // 0–1
    var leanMassKg: Double = 0
    var vo2Max: Double = 0               // mL/kg/min
    var restingHR: Double = 0
    var hrv: Double = 0
    var hrvBaseline: Double = 0          // 30-day rolling average
    var recoveryScore: Double? = nil     // WHOOP 0–100
    var sleepHours: Double = 0
    var steps: Double = 0
    var weeklyExerciseMinutes: Double = 0
    var trainingMonths: Int = 0          // months since first logged workout

    /// Assemble a snapshot from the live services.
    static func build(hk: HealthKitService, whoop: WhoopSnapshot, store: WorkoutStore) -> UserMetrics {
        var m = UserMetrics()
        switch hk.biologicalSex {
        case .male:   m.sex = .male
        case .female: m.sex = .female
        default:      m.sex = .unknown
        }
        m.age = hk.age > 0 ? hk.age : nil
        m.weightKg = hk.weight
        m.heightM = hk.heightMeters
        m.bodyFatFraction = hk.bodyFat
        m.leanMassKg = hk.leanMass
        m.vo2Max = hk.vo2Max
        m.restingHR = whoop.restingHR ?? hk.restingHR
        m.hrv = whoop.hrv ?? hk.hrvMssd
        if !hk.hrvHistory.isEmpty {
            m.hrvBaseline = hk.hrvHistory.map(\.1).reduce(0, +) / Double(hk.hrvHistory.count)
        }
        m.recoveryScore = whoop.recoveryScore
        m.sleepHours = hk.sleepHours
        m.steps = hk.steps
        m.weeklyExerciseMinutes = hk.weeklyExerciseMinutes
        if let first = store.sessions.map(\.startDate).min() {
            m.trainingMonths = max(0, Calendar.current.dateComponents([.month], from: first, to: Date()).month ?? 0)
        }
        return m
    }
}
