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
    let id: Int
    let cycleId: Int
    let sleepId: Int
    let userId: Int
    let createdAt: Date
    let updatedAt: Date
    let score: WhoopRecoveryScore?

    enum CodingKeys: String, CodingKey {
        case id, sleepId = "sleep_id", cycleId = "cycle_id",
             userId = "user_id", createdAt = "created_at",
             updatedAt = "updated_at", score
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
    let id: Int
    let startTime: Date
    let endTime: Date
    let score: WhoopSleepScore?

    enum CodingKeys: String, CodingKey {
        case id, startTime = "start_time", endTime = "end_time", score
    }
}

struct WhoopSleepScore: Codable {
    let stagesSummary: WhoopSleepStages
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
    let startTime: Date
    let endTime: Date?
    let score: WhoopCycleScore?

    enum CodingKeys: String, CodingKey {
        case id, startTime = "start_time", endTime = "end_time", score
    }
}

struct WhoopCycleScore: Codable {
    let strain: Double
    let kilojoule: Double
    let averageHeartRate: Double
    let maxHeartRate: Double

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
