import SwiftUI

extension Date {
    var localTimeZoneString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 4 * 3600) // GMT+4
        return formatter.string(from: self)
    }
    
    var localDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone(secondsFromGMT: SECONDS_FROM_GMT_TO_UTC)!
        return formatter.string(from: self)
    }
    
    func roundedDownToTimeWindow(windowDuration: TimeInterval = LOCATION_INTERVAL_DURATION_IN_SEC) -> Date {
        let interval = timeIntervalSinceReferenceDate
        let remainder = interval.truncatingRemainder(dividingBy: windowDuration)
        return self.addingTimeInterval(-remainder)
    }
}
