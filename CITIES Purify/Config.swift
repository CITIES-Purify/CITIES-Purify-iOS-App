import Foundation

struct Config {
    // URL for the backend API
    static var baseURL: String = nil
        
    // Endpoints
    static var periodsEndpoint: String {
        return "\(baseURL)/periods"
    }
    
    static func purifiersEndpoint(id: String? = nil) -> String {
        if let id = id {
            return "\(baseURL)/purifiers/\(id)"
        } else {
            return "\(baseURL)/purifiers"
        }
    }
    
    static func dailyRecords(pseudonym: String) -> String {
        return "\(baseURL)/daily-records/\(pseudonym)"
    }
    
    static func participantEndpoint(pseudonym: String) -> String {
        return "\(baseURL)/participant/\(pseudonym)"
    }
    
    static func samplesEndpoint(pseudonym: String) -> String {
        return "\(baseURL)/samples/\(pseudonym)"
    }
    
    static func heartBeatSubsamplesEndpoint(pseudonym: String) -> String {
        return "\(baseURL)/heart-beat-subsamples/\(pseudonym)"
    }
    
    static func proximityEndpoint(pseudonym: String) -> String {
        return "\(baseURL)/proximity/\(pseudonym)"
    }
    
    static func deleteSamplesEndpoint(pseudonym: String) -> String {
        return "\(baseURL)/samples/\(pseudonym)"
    }
    
    static func surveyEndpoint(pseudonym: String, dateString: String, isSample: Bool = false) -> String {
        return nil
    }
    
    static func locationsEndpoint(pseudonym: String) -> String {
        return "\(baseURL)/locations/\(pseudonym)"
    }
}
