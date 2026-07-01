import XCTest
import MuscleMap
@testable import HealthAggregator

/// `MuscleBalanceEngine` is pure and testable without any UI, per the `InsightsEngine`/
/// `ProgressionEngine` convention. These tests cover fractional-volume aggregation, the
/// minimum-sample gate, status boundaries, and the antagonist-ratio math.
final class MuscleBalanceEngineTests: XCTestCase {

    /// A session old enough on its own to satisfy the 14-day minimum-history gate, using an
    /// exercise that doesn't interfere with the muscles under test in each case below.
    private func anchor(daysAgo: Int = 20) -> WorkoutSession {
        Fixture.session(daysAgo: daysAgo, exercise: "Machine Tricep Extension", sets: [(20, 12)])
    }

    // MARK: - Fractional volume

    func testWeeklyVolumePrimaryGetsFullSecondaryGetsHalfCredit() {
        // Bench Press: primary Chest, secondary Triceps + Front Delts (→ .deltoids via balanceGroup)
        let session = Fixture.session(daysAgo: 1, exercise: "Bench Press", sets: [(60, 8), (60, 8), (60, 8)])
        let volumes = MuscleBalanceEngine.weeklyVolume(sessions: [session])
        XCTAssertEqual(volumes[.chest] ?? 0, 3.0, accuracy: 0.01)
        XCTAssertEqual(volumes[.triceps] ?? 0, 1.5, accuracy: 0.01)
        XCTAssertEqual(volumes[.deltoids] ?? 0, 1.5, accuracy: 0.01)
    }

    func testWeeklyVolumeExcludesSessionsOutsideWindow() {
        let session = Fixture.session(daysAgo: 10, exercise: "Barbell Curl", sets: [(20, 8)])
        let volumes = MuscleBalanceEngine.weeklyVolume(sessions: [session], windowDays: 7)
        XCTAssertNil(volumes[.biceps], "A session 10 days ago is outside a 7-day window")
    }

    func testWeeklyVolumeSkipsUnrecognizedExerciseNames() {
        let session = Fixture.session(daysAgo: 1, exercise: "Totally Made Up Exercise", sets: [(20, 8)])
        let volumes = MuscleBalanceEngine.weeklyVolume(sessions: [session])
        XCTAssertTrue(volumes.isEmpty)
    }

    // MARK: - Minimum sample gate

    func testNoDataGateWhenHistoryTooRecent() {
        // Every session is within the last few days — no 14-day baseline yet.
        let sessions = [Fixture.session(daysAgo: 1, exercise: "Barbell Curl", sets: Array(repeating: (20.0, 8), count: 10))]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertFalse(report.hasEnoughData)
        XCTAssertNil(report.overallScore)
        XCTAssertTrue(report.perMuscle.allSatisfy { $0.status == .noData })
        XCTAssertTrue(report.antagonistPairs.isEmpty)
    }

    // MARK: - Status boundaries

    func testStatusUnderBelowMEV() {
        // Biceps MEV = 6. Two sets this week, plus a 20-day-old anchor for the history gate.
        let sessions = [anchor(), Fixture.session(daysAgo: 1, exercise: "Barbell Curl", sets: [(20, 8), (20, 8)])]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        let biceps = report.perMuscle.first { $0.group == .biceps }
        XCTAssertEqual(biceps?.status, .under)
        XCTAssertEqual(biceps?.weeklySets ?? 0, 2, accuracy: 0.01)
    }

    func testStatusOptimalWithinRange() {
        // Biceps MEV 6 / MRV 20 — 10 sets should land in range.
        let sessions = [anchor(), Fixture.session(daysAgo: 1, exercise: "Barbell Curl", sets: Array(repeating: (20.0, 8), count: 10))]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertEqual(report.perMuscle.first { $0.group == .biceps }?.status, .optimal)
    }

    func testStatusOverAboveMRV() {
        // Biceps MRV = 20 — 25 sets should exceed it.
        let sessions = [anchor(), Fixture.session(daysAgo: 1, exercise: "Barbell Curl", sets: Array(repeating: (20.0, 8), count: 25))]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertEqual(report.perMuscle.first { $0.group == .biceps }?.status, .over)
    }

    func testStatusNoDataWhenZeroSetsThisWeek() {
        let sessions = [anchor()]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertEqual(report.perMuscle.first { $0.group == .biceps }?.status, .noData)
    }

    // MARK: - Antagonist ratios

    func testHamstringQuadRatioBalanced() {
        // Leg Extension = Quads only, Leg Curl (Lying) = Hamstrings only — isolates the ratio.
        let sessions = [
            anchor(),
            Fixture.session(daysAgo: 1, exercise: "Leg Extension", sets: Array(repeating: (40.0, 10), count: 10)),
            Fixture.session(daysAgo: 2, exercise: "Leg Curl (Lying)", sets: Array(repeating: (30.0, 10), count: 7)),
        ]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        let pair = report.antagonistPairs.first { $0.label == "Hamstrings : Quads" }
        XCTAssertNotNil(pair)
        XCTAssertEqual(pair?.ratio ?? 0, 0.7, accuracy: 0.01)
        XCTAssertTrue(pair?.isBalanced ?? false, "0.7 is within the 0.6–0.8 target")
    }

    func testHamstringQuadRatioQuadDominantFlagged() {
        let sessions = [
            anchor(),
            Fixture.session(daysAgo: 1, exercise: "Leg Extension", sets: Array(repeating: (40.0, 10), count: 10)),
            Fixture.session(daysAgo: 2, exercise: "Leg Curl (Lying)", sets: [(30, 10), (30, 10)]),
        ]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        let pair = report.antagonistPairs.first { $0.label == "Hamstrings : Quads" }
        XCTAssertFalse(pair?.isBalanced ?? true, "2:10 = 0.2 is well outside the 0.6–0.8 target")
    }

    func testAntagonistRatioNilWhenNoData() {
        let sessions = [anchor()]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertTrue(report.antagonistPairs.isEmpty, "No leg volume logged this week — nothing to compute a ratio from")
    }

    // MARK: - Recommendations

    func testRecommendationsPrioritizeRehabRelevantMuscle() {
        // Biceps (not rehab-relevant) and hamstrings (rehab-relevant) both under this week.
        let sessions = [
            anchor(),
            Fixture.session(daysAgo: 1, exercise: "Barbell Curl", sets: [(20, 8)]),
            Fixture.session(daysAgo: 2, exercise: "Leg Curl (Lying)", sets: [(30, 8)]),
        ]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertEqual(report.recommendations.first?.group, .hamstring)
    }

    func testAntagonistPairMusclesCoverBothSidesForMatching() {
        // Regression: `label` alone can't be used to find a pair for a given muscle — "Pull : Push"
        // never mentions "Chest" or "Back" by name, so callers must match on `.muscles` instead.
        let sessions = [
            anchor(),
            Fixture.session(daysAgo: 1, exercise: "Bench Press", sets: Array(repeating: (60.0, 8), count: 6)),
            Fixture.session(daysAgo: 2, exercise: "Barbell Row", sets: Array(repeating: (60.0, 8), count: 6)),
        ]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        let pullPush = report.antagonistPairs.first { $0.label == "Pull : Push" }
        XCTAssertNotNil(pullPush)
        XCTAssertTrue(pullPush?.muscles.contains(.chest) ?? false)
        XCTAssertTrue(pullPush?.muscles.contains(.upperBack) ?? false)
        XCTAssertFalse(pullPush?.label.localizedCaseInsensitiveContains("Chest") ?? true,
                        "The label itself doesn't name any muscle — that's exactly why `.muscles` exists")
    }

    func testTopAlertCandidateMatchesFirstRecommendation() {
        let sessions = [anchor(), Fixture.session(daysAgo: 1, exercise: "Barbell Curl", sets: [(20, 8)])]
        let report = MuscleBalanceEngine.balanceReport(sessions: sessions)
        XCTAssertEqual(MuscleBalanceEngine.topAlertCandidate(from: report)?.group, report.recommendations.first?.group)
    }
}
