import XCTest
@testable import HealthAggregator

/// Guards the metric catalog that powers the unified detail page + dropdown. If a metric id is
/// renamed/removed, the MetricNavLink call sites (Body/Recovery/Dashboard) would silently open the
/// wrong metric — these tests catch that.
@MainActor
final class MetricCatalogTests: XCTestCase {

    func testCatalogContainsAllExpectedMetrics() {
        let metrics = MetricCatalog.all(hk: HealthKitService(), whoop: WhoopSnapshot())
        let ids = Set(metrics.map(\.id))
        let expected: Set<String> = ["steps", "weight", "bodyfat", "leanmass", "sleep",
                                     "calories", "hrv", "restinghr", "recovery", "strain"]
        XCTAssertEqual(ids, expected, "Catalog metric ids drifted from the MetricNavLink call sites")
    }

    func testEveryMetricHasTitleAndUniqueId() {
        let metrics = MetricCatalog.all(hk: HealthKitService(), whoop: WhoopSnapshot())
        XCTAssertEqual(Set(metrics.map(\.id)).count, metrics.count, "Duplicate metric id")
        for m in metrics {
            XCTAssertFalse(m.title.isEmpty, "Empty title for \(m.id)")
            XCTAssertFalse(m.icon.isEmpty, "Empty icon for \(m.id)")
        }
    }

    func testWhoopOnlyMetricsHaveNoHistoryMessage() {
        let metrics = MetricCatalog.all(hk: HealthKitService(), whoop: WhoopSnapshot())
        for id in ["recovery", "strain"] {
            let m = metrics.first { $0.id == id }
            XCTAssertNotNil(m?.noDataMessage, "\(id) should explain its missing history")
            XCTAssertTrue(m?.history.isEmpty ?? false)
        }
    }

    func testRecoveryReflectsWhoopSnapshot() {
        var snap = WhoopSnapshot()
        snap.recoveryScore = 72
        snap.strain = 14.2
        let metrics = MetricCatalog.all(hk: HealthKitService(), whoop: snap)
        XCTAssertEqual(metrics.first { $0.id == "recovery" }?.current, 72)
        XCTAssertEqual(metrics.first { $0.id == "strain" }?.current ?? 0, 14.2, accuracy: 0.001)
    }

    func testChartPeriodDays() {
        XCTAssertEqual(ChartPeriod.week.days, 7)
        XCTAssertEqual(ChartPeriod.month.days, 30)
        XCTAssertEqual(ChartPeriod.quarter.days, 90)
        XCTAssertEqual(ChartPeriod.year.days, 365)
    }
}
