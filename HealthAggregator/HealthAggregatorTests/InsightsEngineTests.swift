import XCTest
@testable import HealthAggregator

/// Locks in the science-backed coaching thresholds. If a number changes here, docs/SCIENCE.md
/// must change too — these tests are the tripwire.
final class InsightsEngineTests: XCTestCase {

    // MARK: - Body fat (§1)

    func testBodyFatNilWhenNoData() {
        XCTAssertNil(InsightsEngine.bodyFat(Fixture.metrics(bodyFatFraction: 0)))
    }

    func testBodyFatMaleAthletic() {
        let i = InsightsEngine.bodyFat(Fixture.metrics(sex: .male, bodyFatFraction: 0.12))
        XCTAssertEqual(i?.rating.label, MetricRating.strong.label)
    }

    func testBodyFatMaleElevated() {
        let i = InsightsEngine.bodyFat(Fixture.metrics(sex: .male, age: 30, bodyFatFraction: 0.30))
        XCTAssertEqual(i?.rating.label, MetricRating.elevated.label)
    }

    func testBodyFatBelowEssentialIsLow() {
        let i = InsightsEngine.bodyFat(Fixture.metrics(sex: .male, bodyFatFraction: 0.03))
        XCTAssertEqual(i?.rating.label, MetricRating.low.label)
    }

    func testBodyFatFemaleUsesFemaleScale() {
        // 22% is "fitness/healthy" for women but would be elevated on the male scale.
        let i = InsightsEngine.bodyFat(Fixture.metrics(sex: .female, bodyFatFraction: 0.22))
        XCTAssertEqual(i?.rating.label, MetricRating.healthy.label)
    }

    // MARK: - Protein (§8)

    func testProteinTargetRange() {
        let t = InsightsEngine.proteinTarget(Fixture.metrics(weightKg: 80))
        XCTAssertEqual(t?.low, 128)   // 1.6 * 80
        XCTAssertEqual(t?.high, 176)  // 2.2 * 80
    }

    func testProteinNilWithoutWeight() {
        XCTAssertNil(InsightsEngine.proteinTarget(Fixture.metrics(weightKg: 0)))
    }

    // MARK: - VO2max (§5)

    func testVO2ReferenceByAgeAndSex() {
        XCTAssertEqual(InsightsEngine.vo2Reference(age: 25, sex: .male), 48)
        XCTAssertEqual(InsightsEngine.vo2Reference(age: 35, sex: .male), 43)
        XCTAssertEqual(InsightsEngine.vo2Reference(age: 45, sex: .female), 31)
        XCTAssertEqual(InsightsEngine.vo2Reference(age: 95, sex: .male), 24, "Clamps to oldest bucket")
        XCTAssertEqual(InsightsEngine.vo2Reference(age: 10, sex: .male), 48, "Clamps to youngest bucket")
    }

    func testVO2MaxStrongWhenAboveReference() {
        let i = InsightsEngine.vo2Max(Fixture.metrics(sex: .male, age: 30, vo2Max: 50))
        XCTAssertNotNil(i)
        XCTAssertEqual(i?.rating.label, MetricRating.strong.label)
    }

    // MARK: - Steps (§7)

    func testStepsHealthyAtThreshold() {
        XCTAssertEqual(InsightsEngine.steps(Fixture.metrics(age: 30, steps: 9000))?.rating.label,
                       MetricRating.healthy.label)
    }

    func testStepsBelowTarget() {
        XCTAssertEqual(InsightsEngine.steps(Fixture.metrics(age: 30, steps: 4000))?.rating.label,
                       MetricRating.belowTarget.label)
    }

    func testStepsOlderAdultLowerThreshold() {
        // 7200 steps clears the 7000 bar for a 65-year-old but not the 8000 bar for a 30-year-old.
        XCTAssertEqual(InsightsEngine.steps(Fixture.metrics(age: 65, steps: 7200))?.rating.label,
                       MetricRating.healthy.label)
        XCTAssertEqual(InsightsEngine.steps(Fixture.metrics(age: 30, steps: 7200))?.rating.label,
                       MetricRating.belowTarget.label)
    }

    // MARK: - Sleep (§9)

    func testSleepHealthyAndBelow() {
        XCTAssertEqual(InsightsEngine.sleep(Fixture.metrics(sleepHours: 8))?.rating.label,
                       MetricRating.healthy.label)
        XCTAssertEqual(InsightsEngine.sleep(Fixture.metrics(sleepHours: 6))?.rating.label,
                       MetricRating.belowTarget.label)
    }

    // MARK: - Cardio volume (§6)

    func testCardioVolumeBands() {
        XCTAssertEqual(InsightsEngine.cardioVolume(Fixture.metrics(weeklyExerciseMinutes: 160))?.rating.label,
                       MetricRating.healthy.label)
        XCTAssertEqual(InsightsEngine.cardioVolume(Fixture.metrics(weeklyExerciseMinutes: 100))?.rating.label,
                       MetricRating.belowTarget.label)
        XCTAssertEqual(InsightsEngine.cardioVolume(Fixture.metrics(weeklyExerciseMinutes: 30))?.rating.label,
                       MetricRating.low.label)
    }

    // MARK: - Recovery guidance (§10)

    func testRecoveryGuidanceNilWithoutScore() {
        XCTAssertNil(InsightsEngine.recoveryGuidance(Fixture.metrics(recoveryScore: nil)))
    }

    func testRecoveryGuidanceBands() {
        XCTAssertEqual(InsightsEngine.recoveryGuidance(Fixture.metrics(recoveryScore: 80))?.headline, "Primed to perform")
        XCTAssertEqual(InsightsEngine.recoveryGuidance(Fixture.metrics(recoveryScore: 50))?.headline, "Moderate recovery")
        XCTAssertEqual(InsightsEngine.recoveryGuidance(Fixture.metrics(recoveryScore: 20))?.headline, "Prioritize recovery")
    }

    func testRecoveryGuidanceFlagsLowHRV() {
        let m = Fixture.metrics(hrv: 40, hrvBaseline: 60, recoveryScore: 75)  // 40 < 0.85*60=51
        let g = InsightsEngine.recoveryGuidance(m)
        XCTAssertTrue(g?.notes.contains(where: { $0.contains("HRV") }) ?? false)
    }

    func testRecoveryGuidanceFlagsLowSleep() {
        let m = Fixture.metrics(recoveryScore: 75, sleepHours: 5)
        let g = InsightsEngine.recoveryGuidance(m)
        XCTAssertTrue(g?.notes.contains(where: { $0.contains("sleep") }) ?? false)
    }

    // MARK: - Aggregator robustness

    func testBodyInsightsDoesNotCrashOnEmptyMetrics() {
        let insights = InsightsEngine.bodyInsights(Fixture.metrics())
        // Cardio volume always returns a value (0 min → "low"), so we expect at least that one.
        XCTAssertTrue(insights.contains { $0.title.contains("Cardio") })
    }

    func testMuscleNeedsHeight() {
        XCTAssertNil(InsightsEngine.muscle(Fixture.metrics(weightKg: 80, heightM: 0, bodyFatFraction: 0.15)))
        XCTAssertNotNil(InsightsEngine.muscle(Fixture.metrics(weightKg: 80, heightM: 1.8, bodyFatFraction: 0.15)))
    }
}
