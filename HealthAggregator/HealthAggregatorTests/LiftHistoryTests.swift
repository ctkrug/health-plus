import XCTest
@testable import HealthAggregator

/// `LiftHistory` turns raw session history into the per-lift chart's data points. These tests lock
/// in the aggregation rules (top set, e1RM, volume, PR flag, name matching) against synthetic fixtures.
final class LiftHistoryTests: XCTestCase {

    func testPointsEmptyWhenExerciseNeverLogged() {
        let history = [Fixture.session(daysAgo: 2, exercise: "Squat", sets: [(100, 5)])]
        XCTAssertTrue(LiftHistory.points(for: "Bench Press", in: history).isEmpty)
    }

    func testOnePointPerSession() {
        let history = [
            Fixture.session(daysAgo: 10, exercise: "Bench Press", sets: [(60, 8), (60, 8)]),
            Fixture.session(daysAgo: 3, exercise: "Bench Press", sets: [(65, 6), (65, 6), (65, 6)]),
        ]
        let points = LiftHistory.points(for: "Bench Press", in: history)
        XCTAssertEqual(points.count, 2)
        XCTAssertLessThan(points[0].date, points[1].date, "Should be sorted oldest first")
    }

    func testTopWeightAndVolume() {
        let history = [Fixture.session(daysAgo: 1, exercise: "Squat", sets: [(80, 8), (90, 5), (85, 6)])]
        let point = LiftHistory.points(for: "Squat", in: history).first
        XCTAssertEqual(point?.topWeightKg ?? 0, 90, accuracy: 0.01, "Top weight is the heaviest completed set")
        // volume = 80*8 + 90*5 + 85*6 = 640 + 450 + 510 = 1600
        XCTAssertEqual(point?.totalVolume ?? 0, 1600, accuracy: 0.01)
    }

    func testEstimated1RMUsesBestSetNotTopWeightSet() {
        // A lighter, higher-rep set can have a higher estimated 1RM (Epley) than the heaviest set.
        let history = [Fixture.session(daysAgo: 1, exercise: "Row", sets: [(100, 1), (60, 15)])]
        let point = LiftHistory.points(for: "Row", in: history).first
        // 100*(1+1/30)=103.3, 60*(1+15/30)=90 → best is the 100x1 set
        XCTAssertEqual(point?.estimated1RM ?? 0, 103.333, accuracy: 0.01)
    }

    func testNameMatchingIsCaseAndWhitespaceInsensitive() {
        let history = [Fixture.session(daysAgo: 1, exercise: "  Bench press ", sets: [(60, 8)])]
        XCTAssertEqual(LiftHistory.points(for: "bench press", in: history).count, 1)
    }

    func testIsPRFlagCarriesThrough() {
        var session = Fixture.session(daysAgo: 1, exercise: "Deadlift", sets: [(140, 5)])
        session.exercises[0].sets[0].isPR = true
        let point = LiftHistory.points(for: "Deadlift", in: [session]).first
        XCTAssertEqual(point?.isPR, true)
    }

    func testIncompleteSessionsExcludedFromHistory() {
        let history = [Fixture.session(daysAgo: 1, exercise: "Bench Press", sets: [(60, 8)], completed: false)]
        XCTAssertTrue(LiftHistory.points(for: "Bench Press", in: history).isEmpty,
                       "Uncompleted sets shouldn't produce a data point")
    }

    func testTrainedExerciseNamesDeduplicatesAndSorts() {
        let history = [
            Fixture.session(daysAgo: 5, exercise: "Squat", sets: [(100, 5)]),
            Fixture.session(daysAgo: 3, exercise: "Bench Press", sets: [(60, 8)]),
            Fixture.session(daysAgo: 1, exercise: "Squat", sets: [(105, 5)]),
        ]
        XCTAssertEqual(LiftHistory.trainedExerciseNames(in: history), ["Bench Press", "Squat"])
    }
}
