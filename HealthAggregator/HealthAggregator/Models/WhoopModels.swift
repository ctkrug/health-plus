import Foundation

// MARK: - WHOOP API Models

struct WhoopTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct WhoopRecovery: Codable, Identifiable {
    // v2: sleep_id is a UUID string (was Int in v1). Only `score` is consumed by the app,
    // so every other field is optional/tolerant — a field type change must not nuke the decode.
    let cycleId: Int?
    let sleepId: String?
    let userId: Int?
    let score: WhoopRecoveryScore?

    var id: String { sleepId ?? "\(cycleId ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case cycleId = "cycle_id"
        case sleepId = "sleep_id"
        case userId = "user_id"
        case score
    }
}

struct WhoopRecoveryScore: Codable {
    let userCalibrating: Bool?
    let recoveryScore: Double?
    let restingHeartRate: Double?
    let hrvRmssdMilli: Double?
    let spo2Percentage: Double?
    let skinTempCelsius: Double?

    enum CodingKeys: String, CodingKey {
        case userCalibrating = "user_calibrating"
        case recoveryScore = "recovery_score"
        case restingHeartRate = "resting_heart_rate"
        case hrvRmssdMilli = "hrv_rmssd_milli"
        case spo2Percentage = "spo2_percentage"
        case skinTempCelsius = "skin_temp_celsius"
    }
}

struct WhoopSleep: Codable, Identifiable {
    let id: String   // v2: UUID string (was Int in v1)
    let score: WhoopSleepScore?
}

struct WhoopSleepScore: Codable {
    let stagesSummary: WhoopSleepStages?
    let sleepPerformancePercentage: Double?
    let sleepConsistencyPercentage: Double?
    let sleepEfficiencyPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case stagesSummary = "stage_summary"
        case sleepPerformancePercentage = "sleep_performance_percentage"
        case sleepConsistencyPercentage = "sleep_consistency_percentage"
        case sleepEfficiencyPercentage = "sleep_efficiency_percentage"
    }
}

struct WhoopSleepStages: Codable {
    let totalInBedTimeMilli: Int
    let totalAwakeTimeMilli: Int
    let totalNoDataTimeMilli: Int
    let totalLightSleepTimeMilli: Int
    let totalSlowWaveSleepTimeMilli: Int
    let totalRemSleepTimeMilli: Int
    let sleepCycleCount: Int
    let disturbanceCount: Int

    enum CodingKeys: String, CodingKey {
        case totalInBedTimeMilli = "total_in_bed_time_milli"
        case totalAwakeTimeMilli = "total_awake_time_milli"
        case totalNoDataTimeMilli = "total_no_data_time_milli"
        case totalLightSleepTimeMilli = "total_light_sleep_time_milli"
        case totalSlowWaveSleepTimeMilli = "total_slow_wave_sleep_time_milli"
        case totalRemSleepTimeMilli = "total_rem_sleep_time_milli"
        case sleepCycleCount = "sleep_cycle_count"
        case disturbanceCount = "disturbance_count"
    }
}

struct WhoopCycle: Codable, Identifiable {
    let id: Int
    let score: WhoopCycleScore?
}

struct WhoopCycleScore: Codable {
    // Optional: an in-progress cycle can be missing individual fields without breaking the decode.
    let strain: Double?
    let kilojoule: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?

    enum CodingKeys: String, CodingKey {
        case strain, kilojoule
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
    }
}

// MARK: - App-level WHOOP snapshot

struct WhoopSnapshot: Codable {
    var recoveryScore: Double?
    var hrv: Double?
    var restingHR: Double?
    var strain: Double?
    var sleepPerformance: Double?
    var lastUpdated: Date?

    static var empty: WhoopSnapshot { .init() }

    var isConnected: Bool { lastUpdated != nil }
}
