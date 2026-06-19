import Foundation

/// Personalized, science-backed coaching logic. ALL thresholds are documented (with citations)
/// in docs/SCIENCE.md — each function notes the section it implements. Keep them in lockstep.
///
/// Pure functions only: input a `UserMetrics` snapshot, output insights. No I/O, easy to unit-test
/// and to tune. Functions return `nil` when there isn't enough data, so the UI can hide them.
enum InsightsEngine {

    // MARK: Aggregators

    /// Body-composition + fitness insights for the Body tab, in display order.
    static func bodyInsights(_ m: UserMetrics) -> [MetricInsight] {
        [bodyFat(m), muscle(m), vo2Max(m), cardioVolume(m)].compactMap { $0 }
    }

    // MARK: - §1 Body fat

    static func bodyFat(_ m: UserMetrics) -> MetricInsight? {
        guard m.bodyFatFraction > 0 else { return nil }
        let pct = m.bodyFatFraction * 100

        // ACE/ACSM category ceilings + essential floor, by sex.
        let essentialFloor: Double
        let athleticHi: Double
        let fitnessHi: Double
        var averageHi: Double
        let targetText: String
        switch m.sex {
        case .female:
            essentialFloor = 13; athleticHi = 20; fitnessHi = 24; averageHi = 31
            targetText = "Target 18–25%"
        default: // male / unknown default to male scale
            essentialFloor = 5; athleticHi = 13; fitnessHi = 17; averageHi = 24
            targetText = "Target 10–17%"
        }
        // Age adjustment: acceptable body fat rises ~1% per decade over 40 (§1).
        if let age = m.age, age > 40 { averageHi += Double((age - 40) / 10 + 1) }

        let rating: MetricRating
        let detail: String
        if pct < essentialFloor {
            rating = .low
            detail = "Below essential body fat — extremely lean can affect hormones and recovery."
        } else if pct <= athleticHi {
            rating = .strong
            detail = "Athletic range. Great composition — focus on maintaining muscle."
        } else if pct <= fitnessHi {
            rating = .healthy
            detail = "Lean and healthy. You're in the fitness range most people aim for."
        } else if pct <= averageHi {
            rating = .healthy
            detail = "Acceptable range. A small cut would bring you into the lean/fitness zone."
        } else {
            rating = .elevated
            detail = "Above the healthy range — a gradual fat-loss phase would improve health markers."
        }

        return MetricInsight(
            icon: "drop.fill", title: "Body Fat",
            value: String(format: "%.1f%%", pct),
            rating: rating, target: targetText, detail: detail
        )
    }

    // MARK: - §2/§3 Muscle mass (normalized FFMI) + realistic gain rate

    static func muscle(_ m: UserMetrics) -> MetricInsight? {
        guard m.heightM > 0 else { return nil }
        let ffm = m.leanMassKg > 0
            ? m.leanMassKg
            : (m.weightKg > 0 && m.bodyFatFraction > 0 ? m.weightKg * (1 - m.bodyFatFraction) : 0)
        guard ffm > 0 else { return nil }

        let ffmi = ffm / (m.heightM * m.heightM)
        let normFFMI = ffmi + 6.1 * (1.8 - m.heightM)   // normalized to 1.8 m reference (§2)

        // Women run ~3 points lower than men on the same scale.
        let shift: Double = (m.sex == .female) ? -3 : 0
        let belowAvg = 18 + shift
        let avgHi    = 20 + shift
        let strongHi = 23 + shift
        let ceiling  = 25 + shift

        let rating: MetricRating
        if normFFMI < belowAvg      { rating = .belowTarget }
        else if normFFMI < avgHi    { rating = .healthy }
        else if normFFMI < strongHi { rating = .strong }
        else                        { rating = .elite }

        return MetricInsight(
            icon: "figure.strengthtraining.traditional", title: "Muscle Mass (FFMI)",
            value: String(format: "%.1f", normFFMI),
            rating: rating,
            target: String(format: "Natural ceiling ~%.0f", ceiling),
            detail: muscleGainExpectation(m)
        )
    }

    /// §3 — realistic monthly muscle-gain range as a coaching sentence.
    static func muscleGainExpectation(_ m: UserMetrics) -> String {
        guard m.weightKg > 0 else { return "Train each muscle 2×/week and hit your protein target to grow." }
        let level: (name: String, lo: Double, hi: Double)
        switch m.trainingMonths {
        case ..<12:  level = ("a beginner", 0.010, 0.015)
        case 12..<36: level = ("an intermediate", 0.005, 0.010)
        default:     level = ("advanced", 0.0025, 0.005)
        }
        let lbLo = m.weightKg * level.lo * 2.20462
        let lbHi = m.weightKg * level.hi * 2.20462
        return String(format: "As %@, ~%.1f–%.1f lb of muscle per month is realistic with consistent training.",
                      level.name, lbLo, lbHi)
    }

    // MARK: - §5 VO2max

    static func vo2Max(_ m: UserMetrics) -> MetricInsight? {
        guard m.vo2Max > 0 else { return nil }
        let ref = vo2Reference(age: m.age ?? 30, sex: m.sex)
        let ratio = m.vo2Max / ref

        let rating: MetricRating
        let word: String
        switch ratio {
        case ..<0.85:      rating = .belowTarget; word = "below average"
        case 0.85..<1.00:  rating = .healthy;     word = "average"
        case 1.00..<1.15:  rating = .strong;      word = "good"
        case 1.15..<1.30:  rating = .strong;      word = "excellent"
        default:           rating = .elite;       word = "superior"
        }
        return MetricInsight(
            icon: "lungs.fill", title: "VO₂max (Cardio Fitness)",
            value: String(format: "%.0f mL/kg·min", m.vo2Max),
            rating: rating,
            target: String(format: "Age-group median %.0f", ref),
            detail: "Your cardio fitness is \(word) for your age and sex. VO₂max is a top predictor of long-term health."
        )
    }

    /// §5 — FRIEND registry 50th-percentile VO2max by age decade & sex.
    static func vo2Reference(age: Int, sex: UserMetrics.Sex) -> Double {
        let men:   [Double] = [48, 43, 39, 35, 30, 24]   // 20s,30s,40s,50s,60s,70s+
        let women: [Double] = [38, 34, 31, 28, 24, 18]
        let idx = max(0, min(5, (age - 20) / 10))
        return (sex == .female ? women : men)[idx]
    }

    // MARK: - §6 Weekly cardio volume

    static func cardioVolume(_ m: UserMetrics) -> MetricInsight? {
        let mins = m.weeklyExerciseMinutes
        let rating: MetricRating = mins >= 150 ? .healthy : (mins >= 75 ? .belowTarget : .low)
        let detail = mins >= 150
            ? "You're meeting the 150 min/week guideline. Nice consistency."
            : "Aim for 150 min/week of moderate cardio (or 75 vigorous) plus 2 strength days."
        return MetricInsight(
            icon: "figure.run", title: "Weekly Cardio",
            value: "\(Int(mins)) min",
            rating: rating, target: "150 min/wk", detail: detail
        )
    }

    // MARK: - §7 Steps

    static func steps(_ m: UserMetrics) -> MetricInsight? {
        guard m.steps > 0 else { return nil }
        let protective: Double = (m.age ?? 30) >= 60 ? 7000 : 8000
        let rating: MetricRating = m.steps >= protective ? .healthy : .belowTarget
        let detail = m.steps >= protective
            ? "You're in the range linked to lower mortality risk."
            : "Mortality benefit rises up to ~\(Int(protective)) steps/day — a short walk closes the gap."
        return MetricInsight(
            icon: "figure.walk", title: "Steps",
            value: Int(m.steps).formatted(),
            rating: rating, target: "\(Int(protective))+/day", detail: detail
        )
    }

    // MARK: - §8 Protein target (grams/day range)

    static func proteinTarget(_ m: UserMetrics) -> (low: Int, high: Int)? {
        guard m.weightKg > 0 else { return nil }
        return (Int((1.6 * m.weightKg).rounded()), Int((2.2 * m.weightKg).rounded()))
    }

    // MARK: - §9 Sleep

    static func sleep(_ m: UserMetrics) -> MetricInsight? {
        guard m.sleepHours > 0 else { return nil }
        let h = Int(m.sleepHours)
        let min = Int((m.sleepHours.truncatingRemainder(dividingBy: 1)) * 60)
        let rating: MetricRating = m.sleepHours >= 7 ? .healthy : .belowTarget
        let detail = m.sleepHours >= 7
            ? "Solid sleep. 7–9 h supports recovery, hormones, and muscle growth."
            : "Under the 7–9 h target — sleep is when adaptation and recovery happen."
        return MetricInsight(
            icon: "bed.double.fill", title: "Sleep",
            value: "\(h)h \(min)m",
            rating: rating, target: "7–9 h", detail: detail
        )
    }

    // MARK: - §10 Recovery-based training guidance

    static func recoveryGuidance(_ m: UserMetrics) -> RecoveryGuidance? {
        guard let score = m.recoveryScore else { return nil }

        var notes: [String] = []
        if m.hrvBaseline > 0, m.hrv > 0, m.hrv < 0.85 * m.hrvBaseline {
            notes.append(String(format: "HRV %.0f ms is below your 30-day baseline (%.0f ms) — possible fatigue or under-recovery.",
                                m.hrv, m.hrvBaseline))
        }
        if m.sleepHours > 0, m.sleepHours < 7 {
            notes.append("Last night's sleep was under 7 h, which can suppress recovery.")
        }

        switch score {
        case 67...:
            return RecoveryGuidance(
                headline: "Primed to perform",
                recommendation: "Green recovery — a good day to push: heavy lifting or a high-strain session.",
                rating: .healthy, icon: "bolt.fill", notes: notes)
        case 34..<67:
            return RecoveryGuidance(
                headline: "Moderate recovery",
                recommendation: "Train at a steady, moderate effort and auto-regulate. Skip new PRs today.",
                rating: .belowTarget, icon: "equal.circle.fill", notes: notes)
        default:
            return RecoveryGuidance(
                headline: "Prioritize recovery",
                recommendation: "Low recovery — keep it light: easy aerobic work, mobility, or a rest day.",
                rating: .low, icon: "moon.zzz.fill", notes: notes)
        }
    }
}
