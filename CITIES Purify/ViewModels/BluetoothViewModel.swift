import CoreBluetooth
import Foundation
import os

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: BluetoothViewModel.self)
    )
    
    static let shared = BluetoothViewModel()
    
    var centralManager: CBCentralManager!
    let rssiThreshold = -60
    let defaultPeripheralName = "No Device Name"
    
    @Published var connectingToPurifier = false
    @Published var connectedToPurifier = false
    
    @Published var pairingToPurifier = false
    @Published var pairedToPurifier = false
    
    private var connectedSecondsForCurrentInterval: Int = 0
    private var lastConnectionUpdateIntervalStart: Date
    private var lastConnectionUpdate: Date = Date()
    
    @Published var foundDevices: [(name: String, rssi: Int)] = []
    
    private let centralQueue = DispatchQueue(label: "ble.discovery")
    
    override init() {
        lastConnectionUpdateIntervalStart = Date().roundedDownToTimeWindow()
        super.init()
        
        if (ParticipantInfoModel.purifier?.ble_uuid != nil && ParticipantInfoModel.purifier?.alias != nil){
            centralManager = CBCentralManager(delegate: self, queue: centralQueue) // specify the identifierKey here to opt-in State preservation property for the app
        }
    }
    
    func initCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    // MARK: BLE Connection Methods
    func reConnect(_ central: CBCentralManager, shouldResetCentralManagerInstanceIfBleNotOn: Bool = false) {
        if central.state == .poweredOn {
            Self.logger.notice("Bluetooth is powered on.")
            
            if AppState.shared.hasPairedPurifier {
                if let p = BluetoothPeripheral.discoveredPeripheral {
                    connectToPeripheral(p)
                } else {
                    if let uuid = BluetoothPeripheral.peripheralUUID{
                        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                        
                        if let retrievedPeripheral = peripherals.first {
                            // Keep a strong reference to the peripheral
                            // Supplying retrievedPeripheral to `connect` would fail otherwise (Cancelling connection for unused peripheral)
                            BluetoothPeripheral.discoveredPeripheral = retrievedPeripheral
                            
                            if let p = BluetoothPeripheral.discoveredPeripheral{
                                connectToPeripheral(p)
                            }
                        }
                    } else {
                        Self.logger.notice("No saved peripheral to reconnect to. Starting a new scan.")
                        scanAllDevices()
                    }
                }
            }
        } else {
            Self.logger.notice("Bluetooth state: \(central.state.rawValue, privacy: .public)")
            
            if (shouldResetCentralManagerInstanceIfBleNotOn){
                self.centralManager = CBCentralManager(delegate: self, queue: centralQueue)
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.reConnect(central)
    }
    
    func scanAllDevices() {
        guard centralManager.state == .poweredOn else {
            Self.logger.notice("Bluetooth is not powered on. Cannot start scanning.")
            return
        }
        
        if let pseudonym = ParticipantInfoModel.pseudonym {
            if pseudonym.contains(TEST_PARTICIPANT_NAME) {
                DispatchQueue.main.async {
                    self.connectingToPurifier = false
                    self.pairingToPurifier = false
                    
                    self.connectedToPurifier = true
                    self.pairedToPurifier = true
                }
                return
            }
        }
        
        Self.logger.notice("Starting foreground scan for all BLE devices...")
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        DispatchQueue.main.async{
            self.connectingToPurifier = true
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let pseudonym = ParticipantInfoModel.pseudonym {
            if pseudonym.contains(TEST_PARTICIPANT_NAME) {
                DispatchQueue.main.async {
                    self.connectingToPurifier = false
                    self.pairingToPurifier = false
                    
                    self.connectedToPurifier = true
                    self.pairedToPurifier = true
                }
            }
        }
        
        if let purifier = ParticipantInfoModel.purifier, let peripheralName = peripheral.name {
            let sanitizedPeripheralName = peripheralName.sanitized()
            let sanitizedPurifierName = purifier.name.sanitized()
            let sanitizedPurifierBleUUID = purifier.ble_uuid?.sanitized()
            let sanitizedPurifierAlias = purifier.alias?.sanitized()
            
            if [sanitizedPurifierName, sanitizedPurifierBleUUID, sanitizedPurifierAlias].contains(sanitizedPeripheralName) {
                Self.logger.notice("Discovered target device: \(peripheralName, privacy: .public), RSSI: \(RSSI, privacy: .public)")
                
                BluetoothPeripheral.discoveredPeripheral = peripheral
                connectToPeripheral(peripheral)
            }
        }
    }
    
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        if let studyPeriod = ParticipantInfoModel.studyPeriod {
            let today = Date()
            let paddedEndDate = Calendar.current.date(byAdding: .day, value: 1, to: studyPeriod.endDate) ?? studyPeriod.endDate
            
            if paddedEndDate < today {
                Self.logger.notice("Not attempting to connect to purifier as study period has ended.")
                return
            } else {
                Self.logger.notice("Attempting to connect to peripheral: \(peripheral.name ?? self.defaultPeripheralName, privacy: .public)")
                centralManager.connect(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Self.logger.notice("Connected to peripheral: \(peripheral.name ?? self.defaultPeripheralName, privacy: .public)")
        BluetoothPeripheral.connectedPeripheral = peripheral
        BluetoothPeripheral.peripheralUUID = peripheral.identifier
        
        peripheral.delegate = self
        peripheral.discoverServices([BluetoothPeripheral.serviceUUID])
        self.handleConnectionUpdate(previousConnectionState: false)
        
        DispatchQueue.main.async {
            self.connectingToPurifier = false
            self.connectedToPurifier = true
        }
        
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        Self.logger.error("Failed to connect to peripheral: \(peripheral.name ?? self.defaultPeripheralName, privacy: .public)")
        if let error = error {
            Self.logger.error("Error: \(error.localizedDescription, privacy: .public)")
        }
        
        DispatchQueue.main.async {
            self.connectingToPurifier = false
            self.connectedToPurifier = false
        }
        
        // On connection fail, try reConnect immediately
        reConnect(self.centralManager, shouldResetCentralManagerInstanceIfBleNotOn: true)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Self.logger.notice("Disconnected from peripheral: \(peripheral.name ?? self.defaultPeripheralName, privacy: .public)")
        
        BluetoothPeripheral.connectedPeripheral = nil
        self.handleConnectionUpdate(previousConnectionState: true)
        
        DispatchQueue.main.async {
            self.connectedToPurifier = false
            self.pairedToPurifier = false
        }
        
        // On disconnection, try reConnect immediately
        reConnect(self.centralManager, shouldResetCentralManagerInstanceIfBleNotOn: true)
    }
    
    // MARK: Service and Characteristic
    // read known characteristiattemptc so that the device can be "paired" and keep the connection
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            Self.logger.error("Service discovery error: \(error!.localizedDescription, privacy: .public)")
            return
        }
        for service in peripheral.services ?? [] {
            Self.logger.notice("Discovered service: \(service.uuid, privacy: .public)")
            if service.uuid == BluetoothPeripheral.serviceUUID {
                peripheral.discoverCharacteristics([BluetoothPeripheral.characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            Self.logger.error("Characteristic discovery error: \(error!.localizedDescription, privacy: .public)")
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            Self.logger.notice("Discovered characteristics: \(characteristic.uuid, privacy: .public)")
            if characteristic.uuid == BluetoothPeripheral.characteristicUUID {
                // This read will trigger the pairing process if the characteristic is secured.
                peripheral.readValue(for: characteristic)
                DispatchQueue.main.async {
                    self.pairingToPurifier = true
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error as? CBATTError {
            if error.code == .insufficientEncryption {
                DispatchQueue.main.async {
                    AppState.shared.alertTitle = "Error Pairing Purifier"
                    AppState.shared.alertMessage = "PIN code is wrong, please try again"
                    AppState.shared.showAlert = true
                    self.pairingToPurifier = false
                }
            }
            Self.logger.error("Error reading \(characteristic.uuid, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        // Process characteristic.value
        Self.logger.notice("Received value for \(characteristic.uuid, privacy: .public): \(String(describing: characteristic.value), privacy: .public)")
        DispatchQueue.main.async {
            self.pairingToPurifier = false
            self.pairedToPurifier = true
            
            if AppState.shared.hasPairedPurifier { return }
            
            // Alert pairing status the first time it's paired
            AppState.shared.alertTitle = "Pairing Status"
            if let purifier = ParticipantInfoModel.purifier {
                AppState.shared.alertMessage = "Succesfully paired with \(purifier.name) ✅"
            } else {
                AppState.shared.alertMessage = "Succesfully paired"
            }
            AppState.shared.showAlert = true
        }
    }
    
    // MARK: Infering LocationType from BLE Connection
    public func handleConnectionUpdate(previousConnectionState: Bool) {
        let now = Date()
        let elapsedSinceLastConnectionUpdateIntervalStart = now.timeIntervalSince(lastConnectionUpdateIntervalStart)
        
        Self.logger.notice("Now: \(now.localTimeZoneString, privacy: .public)")
        Self.logger.notice("Last connection update interval start: \(self.lastConnectionUpdateIntervalStart.localTimeZoneString, privacy: .public)")
        Self.logger.notice("Last connection update: \(String(describing: self.lastConnectionUpdate.localTimeZoneString), privacy: .public)")
        Self.logger.notice("Elapsed since last connection update interval start: \(elapsedSinceLastConnectionUpdateIntervalStart, privacy: .public) seconds")
        Self.logger.notice("Previous connection state: \(previousConnectionState, privacy: .public)")
        
        // We only care if the device was connected (at-home), if not, we just don't do anything
        if previousConnectionState == true{
            let lastConnectionUpdateIntervalEnd = lastConnectionUpdateIntervalStart.addingTimeInterval(LOCATION_INTERVAL_DURATION_IN_SEC)
            
            // If we're still in the same time interval as the previous event, accumulate connection time
            if (lastConnectionUpdateIntervalStart <= now) && (now <= lastConnectionUpdateIntervalEnd){
                let elapsedSinceLastUpdate = Int(now.timeIntervalSince(self.lastConnectionUpdate))
                self.connectedSecondsForCurrentInterval += elapsedSinceLastUpdate
                Self.logger.notice("Connected seconds for current interval \(self.connectedSecondsForCurrentInterval, privacy: .public) seconds")
                
                if (Double(self.connectedSecondsForCurrentInterval) / LOCATION_INTERVAL_DURATION_IN_SEC >= 0.5){
                    // CASE 1: connection and disconnection times happen within an INTERVAL
                    AppState.shared.locationTypeIntervals.append(
                        LocationTypeInterval(
                            sd: lastConnectionUpdateIntervalStart,
                            ed: lastConnectionUpdateIntervalStart
                                .addingTimeInterval(LOCATION_INTERVAL_DURATION_IN_SEC)
                                .addingTimeInterval(-60)
                        )
                    )
                }
            } else {
                // Reset connection time for current interval
                // by getting the remainder of the division
                self.connectedSecondsForCurrentInterval = Int(elapsedSinceLastConnectionUpdateIntervalStart) % Int(LOCATION_INTERVAL_DURATION_IN_SEC)
                Self.logger.notice("Connected seconds for current interval \(self.connectedSecondsForCurrentInterval, privacy: .public) seconds")
            }
            
            // Else if we've passed at least one full interval, fill in all the historical intervals
            if elapsedSinceLastConnectionUpdateIntervalStart >= LOCATION_INTERVAL_DURATION_IN_SEC{
                // Determine how many full intervals have passed.
                let passedIntervals = Int(elapsedSinceLastConnectionUpdateIntervalStart / LOCATION_INTERVAL_DURATION_IN_SEC)
                var tempWindowStart = lastConnectionUpdateIntervalStart
                
                for i in 0..<passedIntervals + 1 { // +1 to consider the last "unfinished" time interval as well
                    var presencePercentage: Double = 1
                    
                    // Special case for the first interval
                    if i == 0 {
                        let firstIntervalElapsed = tempWindowStart.addingTimeInterval(LOCATION_INTERVAL_DURATION_IN_SEC).timeIntervalSince(self.lastConnectionUpdate)
                        presencePercentage = firstIntervalElapsed / LOCATION_INTERVAL_DURATION_IN_SEC
                    }
                    // Special case for the last "unfinished" interval
                    else if i == passedIntervals {
                        let lastIntervalElapsed = now.timeIntervalSince(tempWindowStart)
                        presencePercentage = lastIntervalElapsed / LOCATION_INTERVAL_DURATION_IN_SEC
                    }
                    
                    Self.logger.notice("Presence percentage: \(presencePercentage, privacy: .public), for interval start: \(tempWindowStart.localTimeZoneString, privacy: .public)")
                    
                    // BLE connection is considered connected for an entire interval if it's connected for more than 50% of that interval
                    if presencePercentage >= 0.5 {
                        // CASE 2: connection and disconnection times spread across multiple INTERVALS
                        AppState.shared.locationTypeIntervals.append(
                            LocationTypeInterval(
                                sd: tempWindowStart,
                                ed: tempWindowStart
                                    .addingTimeInterval(LOCATION_INTERVAL_DURATION_IN_SEC)
                                    .addingTimeInterval(-60)
                            )
                        )
                    }
                    
                    tempWindowStart = tempWindowStart.addingTimeInterval(LOCATION_INTERVAL_DURATION_IN_SEC)
                }
            }
        }
        
        // Reset for the current interval
        self.lastConnectionUpdate = now
        self.lastConnectionUpdateIntervalStart = now.roundedDownToTimeWindow()
        
        Self.logger.notice("New last connection update: \(String(describing: self.lastConnectionUpdate.localTimeZoneString), privacy: .public)")
        Self.logger.notice("New last connection update interval start: \(self.lastConnectionUpdateIntervalStart.localTimeZoneString, privacy: .public)")
        Self.logger.notice("LocationTypeIntervals: \(AppState.shared.locationTypeIntervals, privacy: .public)")
    }
}

extension String {
    func sanitized() -> String {
        return self.replacingOccurrences(of: "[- ]", with: "", options: .regularExpression)
    }
}
