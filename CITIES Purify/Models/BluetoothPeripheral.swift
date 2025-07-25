import Foundation
import CoreBluetooth

class BluetoothPeripheral {
    static var discoveredPeripheral: CBPeripheral?
    static var connectedPeripheral: CBPeripheral?
    static let serviceUUID = CBUUID(string: "1b5ae7e4-f469-440f-a0b4-aed74acd94f8")
    static let characteristicUUID = CBUUID(string: "6f5e9f58-ed60-47a2-bbe4-ec93545b94b6")
    
    static var peripheralUUID: UUID? {
        get {
            // Retrieve the UUID string from UserDefaults and convert it back to a UUID
            if let uuidString = UserDefaults.standard.string(forKey: "peripheralUUID") {
                return UUID(uuidString: uuidString)
            }
            return nil
        }
        set {
            if let newValue = newValue {
                // Save the UUID as a string in UserDefaults
                UserDefaults.standard.set(newValue.uuidString, forKey: "peripheralUUID")
            } else {
                // Remove the value if nil
                UserDefaults.standard.removeObject(forKey: "peripheralUUID")
            }
        }
    }
}
