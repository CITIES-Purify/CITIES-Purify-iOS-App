import Foundation

struct LocationTypeInterval: Codable, Hashable {
    let sd: Date
    let ed: Date
    var lt = "home"
    var lm = "ble"

    func hash(into hasher: inout Hasher) {
        hasher.combine(sd)
        hasher.combine(ed)
        hasher.combine(lt)
        hasher.combine(lm)
    }

    static func == (lhs: LocationTypeInterval, rhs: LocationTypeInterval) -> Bool {
        return lhs.sd == rhs.sd &&
               lhs.ed == rhs.ed &&
               lhs.lt == rhs.lt &&
               lhs.lm == rhs.lm
    }
}
