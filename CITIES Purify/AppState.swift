import Foundation
import Network
import SwiftUI
import HealthKit
import WatchConnectivity

// Ordered in userflow sequence
enum CurrentView: String {
    case splashScreen
    case registration
    case pairing
    case onboarding
    case main
}

class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - HEALTHKIT UPDATE
    public var lastPostTime: Date? {
        get {
            let timestamp = UserDefaults.standard.double(forKey: "lastPostTime")
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastPostTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastPostTime") // Handle nil case
            }
        }
    }
    
    // MARK: NETWORK MONITORING
    private let networkMonitor = NWPathMonitor()
    private let workerQueue = DispatchQueue(label: "Monitor")
    var isConnectedToNetwork = false
    
    // MARK: ALERT
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var currentView: CurrentView
    
    // MARK: APP PROGRESS VARIABLES
    @Published var hasRegisteredParticipant: Bool {
        didSet {
            UserDefaults.standard.set(hasRegisteredParticipant, forKey: "hasRegisteredParticipant")
        }
    }
    
    @Published var hasPairedPurifier: Bool {
        didSet {
            UserDefaults.standard.set(hasPairedPurifier, forKey: "hasPairedPurifier")
        }
    }
    
    @Published var hasOnboarded: Bool {
        didSet {
            UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded")
        }
    }
    
    
    @Published var hasAllowedHealthData: Bool {
        didSet {
            UserDefaults.standard.set(hasAllowedHealthData, forKey: "hasAllowedHealthData")
        }
    }
    
    @Published var hasAskedForNotificationPermissionBefore: Bool {
        didSet {
            UserDefaults.standard.set(hasAskedForNotificationPermissionBefore, forKey: "hasAskedForNotificationPermissionBefore")
        }
    }
    @Published var hasAllowedNotification: Bool = false
    
    @Published var notificationDeviceToken: String {
        didSet {
            UserDefaults.standard.set(notificationDeviceToken, forKey: "notificationDeviceToken")
        }
    }
    
    var scenePhase: ScenePhase?
    
    @Published var queuedRequests: Int = 0 {
        didSet {
            if queuedRequests == 0 {
                syncingTotalRequests = 0
            }
        }
    }
    
    @Published var syncingTotalRequests: Int = 0
    
    public func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasAllowedNotification = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: Location Type Intervals
    public var locationTypeIntervals = [LocationTypeInterval]() {
        didSet {
            // Remove duplicates
            locationTypeIntervals = Array(Set(locationTypeIntervals))

            // Encode and store the updated array
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(self.locationTypeIntervals) {
                UserDefaults.standard.set(encoded, forKey: "locationTypeIntervals")
            }
        }
    }

    
    public func sendLocationTypeIntervals(){
        if (self.locationTypeIntervals.isEmpty) {
            return
        }
        
        guard let pseudonym = ParticipantInfoModel.pseudonym else {
            return
        }
        
        DispatchQueue.main.async{
            self.queuedRequests += 1
            self.syncingTotalRequests += 1
        }
        
        APIService.postLocations(pseudonym: pseudonym, locationTypeIntervals: self.locationTypeIntervals){ success in
            if (success) {
                self.locationTypeIntervals = []
            }
            
            DispatchQueue.main.async{
                self.queuedRequests -= 1
            }
        }
    }
    
    init() {
        // Use local variables to avoid accessing `self` before initialization
        let hasRegisteredParticipant = UserDefaults.standard.object(forKey: "hasRegisteredParticipant") as? Bool ?? false
        let hasPairedPurifier = UserDefaults.standard.object(forKey: "hasPairedPurifier") as? Bool ?? false
        let hasOnboarded = UserDefaults.standard.object(forKey: "hasOnboarded") as? Bool ?? false
        let hasAllowedHealthData = UserDefaults.standard.object(forKey: "hasAllowedHealthData") as? Bool ?? false
        let hasAskedForNotificationPermissionBefore = UserDefaults.standard.object(forKey: "hasAskedForNotificationPermissionBefore") as? Bool ?? false
        let notificationDeviceToken = UserDefaults.standard.object(forKey: "notificationDeviceToken") as? String ?? ""

        // Initialize properties using local variables
        self.hasRegisteredParticipant = hasRegisteredParticipant
        self.hasPairedPurifier = hasPairedPurifier
        self.hasOnboarded = hasOnboarded
        
        let currentView : CurrentView = hasRegisteredParticipant ? .pairing : .splashScreen
        self.currentView = hasPairedPurifier ? .onboarding : currentView
        self.currentView = hasOnboarded ? .main : currentView
        self.hasAllowedHealthData = hasAllowedHealthData
        self.hasAskedForNotificationPermissionBefore = hasAskedForNotificationPermissionBefore
        self.notificationDeviceToken = notificationDeviceToken
        
        // Load existing location types data
        if let locationTypesData = UserDefaults.standard.data(forKey: "locationTypeIntervals") {
            let decoder = JSONDecoder()
            self.locationTypeIntervals = (try? decoder.decode([LocationTypeInterval].self, from: locationTypesData)) ?? []
        }
        
        // Check notification settings
        checkNotificationPermission()
        
        // MARK: NETWORK MONITORING
        networkMonitor.pathUpdateHandler = { path in
            self.isConnectedToNetwork = path.status == .satisfied
            Task {
                await MainActor.run {
                    self.objectWillChange.send()
                }
            }
        }
        networkMonitor.start(queue: workerQueue)
    }
}
