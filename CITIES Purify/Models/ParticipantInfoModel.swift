import Foundation

// StudyPeriod model
struct StudyPeriod: Hashable, Codable {
    let id: Int
    let name: String
    let startDate: Date
    let endDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// DateFormatter for ISO8601 date format used by the backend
extension DateFormatter {
    static let backendDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" // Matches the format from backend
        formatter.timeZone = TimeZone(abbreviation: "UTC") // Backend likely returns UTC dates
        return formatter
    }()
}

// ParticipantInfoModel with methods to handle the study periods
class ParticipantInfoModel {
    static var pseudonym: String? {
        get { UserDefaults.standard.string(forKey: "pseudonym") }
        set { UserDefaults.standard.set(newValue, forKey: "pseudonym") }
    }

    static var studyPeriod: StudyPeriod? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "studyPeriod"),
                  let studyPeriod = try? JSONDecoder().decode(StudyPeriod.self, from: data) else {
                return nil
            }
            return studyPeriod
        }
        set {
            if let newPeriod = newValue, let encodedData = try? JSONEncoder().encode(newPeriod) {
                UserDefaults.standard.set(encodedData, forKey: "studyPeriod")
            } else {
                UserDefaults.standard.removeObject(forKey: "studyPeriod")
            }
        }
    }

    static var purifier: Purifier? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "purifier"),
                  let purifier = try? JSONDecoder().decode(Purifier.self, from: data) else {
                return nil
            }
            return purifier
        }
        set {
            if let newPurifier = newValue,
               let encodedData = try? JSONEncoder().encode(newPurifier) {
                UserDefaults.standard.set(encodedData, forKey: "purifier")
            } else {
                UserDefaults.standard.removeObject(forKey: "purifier")
            }
        }
    }

}
