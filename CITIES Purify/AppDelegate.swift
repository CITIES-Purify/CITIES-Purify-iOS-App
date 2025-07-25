import UIKit
import UserNotifications
import os

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: AppDelegate.self)
    )
    
    // MARK: didFinishLaunchingWithOptions
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]?
    ) -> Bool {
        Self.logger.notice("didFinishLaunchingWithOptions")
        
        // MARK: Registering for push notifications
        UNUserNotificationCenter.current().delegate = self
        
        Task {
            let center = UNUserNotificationCenter.current()
            let authorizationStatus = await center
                .notificationSettings().authorizationStatus
            
            if authorizationStatus == .authorized {
                await MainActor.run {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        // MARK: Set up HealthKit background delivery and observerQuery
        if (AppState.shared.hasAllowedHealthData && AppState.shared.hasOnboarded){
            HealthStore.shared.requestAuthorization { success in
                if success {
                    Self.logger.notice("HealthKit authorization successful!")
                    
                    // Start long-running queries for all types
                    HealthStore.shared.collectDataForAllTypes(isLongRunning: true)
                    
                    // Enable background delivery for all types
                    HealthStore.shared.enableBackgroundDeliveryForAllTypes()
                } else {
                    Self.logger.error("HealthKit authorization failed.")
                }
            }
        }
        return true
    }
    
    // MARK: Handle incoming notifications when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Specify that the notification should be presented as an alert, with sound and badge
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // MARK: Handling the device token (push notification)
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let newToken = deviceToken.reduce("") { $0 + String(format: "%02x", $1) }
        
        // Check if the new token is different and if the permission was asked before
        if AppState.shared.hasAskedForNotificationPermissionBefore &&
            AppState.shared.notificationDeviceToken != newToken {
            
            // Update the token in AppState
            AppState.shared.notificationDeviceToken = newToken
            
            // Call the backend update function
            if let pseudonym = ParticipantInfoModel.pseudonym, !pseudonym.isEmpty {
                APIService.updateNotificationDeviceToken(
                    pseudonym: pseudonym,
                    notificationDeviceToken: newToken
                ) { result in
                    switch result {
                    case .success:
                        Self.logger.notice("Notification device token updated successfully.")
                    case .failure(let error):
                        Self.logger.error("Failed to update notification device token: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
        }
    }
    
    // MARK: Handling silent push notification
    func application(_ application: UIApplication,
         didReceiveRemoteNotification userInfo: [AnyHashable: Any],
         fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let silentNotification = userInfo["aps"] as? [String: AnyObject],
           silentNotification["content-available"] as? Int == 1 {
            // Update BLE connection status whenever received silent notification
            // This is to preserve the historical logs in UserDefaults
            // so they don't get destroyed in case the user force-quit the app
            BluetoothViewModel.shared.handleConnectionUpdate(previousConnectionState: BluetoothViewModel.shared.connectedToPurifier)
        }
    
        // Ending a background operation
        completionHandler(.noData)
    }
}

