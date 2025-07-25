import Foundation

struct Purifier: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let ble_uuid: String?
    let alias: String?
    let availability: [PeriodAvailability]
    
    struct PeriodAvailability: Codable, Hashable {
        let period_id: Int
        let is_available: Bool
    }
}
