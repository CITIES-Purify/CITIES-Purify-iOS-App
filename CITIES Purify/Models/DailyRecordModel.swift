import Foundation

struct DailyRecord: Hashable, Codable {
    let day_of_study: Int
    let date: String
    let is_tracked: Bool
    let is_pending: Bool?
    let dues_in_hours: Int?
}

struct DailyRecordsData: Hashable, Codable {
    let num_total_days: Int?
    let daily_records: [DailyRecord]
    let max_reward: Int?
    let num_tracked_days: Int?
    let num_missed_days: Int?
    let num_pending_days: Int?
    let current_reward: Int?
}

struct DailyRecordsResponse: Codable {
    let records: [String: DailyRecordsData]
    let base_compensation: Int

    let message: String?
}

