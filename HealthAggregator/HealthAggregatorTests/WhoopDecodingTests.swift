import XCTest
@testable import HealthAggregator

/// WHOOP API **v2** JSON decoding (v1 was sunset 2025-10-01). v2 changed sleep IDs to UUID strings.
/// The calibration-null case is a direct regression guard: non-optional score fields once made the
/// whole record fail to decode, so no WHOOP data ever appeared.
final class WhoopDecodingTests: XCTestCase {

    /// Mirrors the private WhoopListResponse in WhoopService (which we can't see even with @testable).
    private struct ListResponse<T: Codable>: Codable { let records: [T] }

    // MARK: - Token

    func testTokenResponseDecodesSnakeCase() throws {
        let json = """
        {"access_token":"abc","refresh_token":"def","expires_in":3600,"token_type":"bearer"}
        """.data(using: .utf8)!
        let token = try JSONDecoder.whoop.decode(WhoopTokenResponse.self, from: json)
        XCTAssertEqual(token.accessToken, "abc")
        XCTAssertEqual(token.refreshToken, "def")
        XCTAssertEqual(token.expiresIn, 3600)
    }

    // MARK: - Recovery (v2: sleep_id is a UUID string)

    func testRecoveryDecodesFullScore() throws {
        let json = """
        {"records":[{
          "cycle_id":1,"sleep_id":"f1e2d3c4-0000-4000-8000-000000000001","user_id":3,
          "score":{"user_calibrating":false,"recovery_score":66,"resting_heart_rate":55,
                   "hrv_rmssd_milli":45.5,"spo2_percentage":97,"skin_temp_celsius":33.2}
        }]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopRecovery>.self, from: json)
        let record = try XCTUnwrap(list.records.first)
        XCTAssertEqual(record.sleepId, "f1e2d3c4-0000-4000-8000-000000000001")
        XCTAssertEqual(record.score?.recoveryScore, 66)
        XCTAssertEqual(record.score?.restingHeartRate, 55)
        XCTAssertEqual(record.score?.hrvRmssdMilli ?? 0, 45.5, accuracy: 0.001)
    }

    /// REGRESSION: during the first ~4 days WHOOP returns null score fields. These must decode
    /// to nil rather than throwing and wiping out cycle/sleep data too.
    func testRecoveryDecodesNullScoreFieldsDuringCalibration() throws {
        let json = """
        {"records":[{
          "cycle_id":1,"sleep_id":"f1e2d3c4-0000-4000-8000-000000000002","user_id":3,
          "score":{"user_calibrating":true,"recovery_score":null,
                   "resting_heart_rate":null,"hrv_rmssd_milli":null}
        }]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopRecovery>.self, from: json)
        let score = try XCTUnwrap(list.records.first?.score)
        XCTAssertNil(score.recoveryScore)
        XCTAssertNil(score.restingHeartRate)
        XCTAssertNil(score.hrvRmssdMilli)
    }

    /// REGRESSION (v2 migration): a field type change (sleep_id int → UUID string) must not break
    /// the decode for the `score` we actually consume. Tolerant optional fields make this safe.
    func testRecoveryDecodesWhenScoreEntirelyMissing() throws {
        let json = """
        {"records":[{"cycle_id":1,"sleep_id":"f1e2d3c4-0000-4000-8000-000000000003","user_id":3}]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopRecovery>.self, from: json)
        XCTAssertNil(list.records.first?.score)
        XCTAssertNotNil(list.records.first?.id, "Identifiable id should still resolve")
    }

    func testEmptyRecordsDecodes() throws {
        let json = #"{"records":[]}"#.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopRecovery>.self, from: json)
        XCTAssertTrue(list.records.isEmpty)
    }

    // MARK: - Cycle (strain)

    func testCycleDecodesStrain() throws {
        let json = """
        {"records":[{"id":1,
          "score":{"strain":12.4,"kilojoule":8000,"average_heart_rate":70,"max_heart_rate":165}}]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopCycle>.self, from: json)
        XCTAssertEqual(list.records.first?.score?.strain ?? 0, 12.4, accuracy: 0.001)
    }

    func testCycleDecodesWithNullScoreFields() throws {
        // The current (in-progress) cycle may not have a finalized strain yet.
        let json = """
        {"records":[{"id":1,"score":{"strain":null,"kilojoule":null,
          "average_heart_rate":null,"max_heart_rate":null}}]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopCycle>.self, from: json)
        XCTAssertNil(list.records.first?.score?.strain)
    }

    // MARK: - Sleep (v2: id is a UUID string)

    func testSleepDecodesPerformance() throws {
        let json = """
        {"records":[{"id":"a1b2c3d4-0000-4000-8000-000000000010",
          "score":{
            "stage_summary":{"total_in_bed_time_milli":28800000,"total_awake_time_milli":1200000,
              "total_no_data_time_milli":0,"total_light_sleep_time_milli":14000000,
              "total_slow_wave_sleep_time_milli":7000000,"total_rem_sleep_time_milli":6600000,
              "sleep_cycle_count":5,"disturbance_count":3},
            "sleep_performance_percentage":88,"sleep_consistency_percentage":75,
            "sleep_efficiency_percentage":92}}]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopSleep>.self, from: json)
        XCTAssertEqual(list.records.first?.id, "a1b2c3d4-0000-4000-8000-000000000010")
        XCTAssertEqual(list.records.first?.score?.sleepPerformancePercentage, 88)
    }

    func testSleepDecodesWithoutStageSummary() throws {
        // stage_summary is optional in v2 model — performance alone must still decode.
        let json = """
        {"records":[{"id":"a1b2c3d4-0000-4000-8000-000000000011",
          "score":{"sleep_performance_percentage":91}}]}
        """.data(using: .utf8)!
        let list = try JSONDecoder.whoop.decode(ListResponse<WhoopSleep>.self, from: json)
        XCTAssertEqual(list.records.first?.score?.sleepPerformancePercentage, 91)
        XCTAssertNil(list.records.first?.score?.stagesSummary)
    }

    // MARK: - Snapshot

    func testSnapshotIsConnectedTracksLastUpdated() {
        var snap = WhoopSnapshot()
        XCTAssertFalse(snap.isConnected)
        snap.lastUpdated = Date()
        XCTAssertTrue(snap.isConnected)
    }
}
