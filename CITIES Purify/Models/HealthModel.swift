struct HealthData: Codable {
    let id: String
    let stid: String?  // e.g., mapped sample type
    let sd: String     // start date as ISO8601 string
    let ed: String     // end date as ISO8601 string
    let hud: Bool      // has undetermined duration
    let v: Double?     // value
    let c: Int?        // count
    let hrmc: Int?     // heart rate motion context
    let av: Int?       // algorithm version
    let tz: String?    // timezone
    let bp: Double?    // barometric pressure
}

struct HeartbeatSubsample: Codable {
    let id: String
    let tsss: Double   // time since start
    let pbg: Bool      // preceded by gap
    let d: Bool        // done
}

