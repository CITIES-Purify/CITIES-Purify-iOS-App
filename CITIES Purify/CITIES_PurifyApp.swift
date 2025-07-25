import SwiftUI
import os

@main
struct CITIES_PurifyApp: App {
    @ObservedObject var appState = AppState.shared
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: CITIES_PurifyApp.self)
    )

    var body: some Scene {
        WindowGroup {
            Group{
                if !appState.isConnectedToNetwork{
                    NetworkErrorView().environmentObject(appState)
                } else {
                    ZStack { // Use a ZStack to overlay the alert on top of all views
                        if (appState.hasOnboarded && !appState.hasAllowedNotification) {
                            Onboarding_Notification()
                                .padding(.vertical)
                                .environmentObject(appState)
                        } else {
                            switch appState.currentView {
                            case .splashScreen:
                                SplashView().environmentObject(appState)
                            case .registration:
                                RegistrationView().environmentObject(appState)
                            case .pairing:
                                PairingView().environmentObject(appState)
                            case .onboarding:
                                OnboardingView().environmentObject(appState)
                            case .main:
                                HomeView().environmentObject(appState)
                            }
                        }
                        
                        if appState.queuedRequests != 0 {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            ProgressView("Syncing \(appState.syncingTotalRequests - appState.queuedRequests)/\(appState.syncingTotalRequests) items")
                            .tint(.white)
                            .font(.body.weight(.bold))
                            .padding()
                            .foregroundStyle(.white)
                            .background(.black)
                            .cornerRadius(8)
                        }
                    }
                    .alert(isPresented: $appState.showAlert) {
                        Alert(
                            title: Text(appState.alertTitle),
                            message: Text(appState.alertMessage),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            Self.logger.notice("Scene phase changed to \(String(describing: newPhase), privacy: .public)")
            appState.scenePhase = newPhase

            switch (newPhase){
            case .active:
                appState.checkNotificationPermission()
                
                // Check if the app has been onboarded and connected to Internet
                if appState.currentView == .main && appState.isConnectedToNetwork {
                    // Call this first to determine locationTypes window to be sent to backend
                    BluetoothViewModel.shared.handleConnectionUpdate(previousConnectionState: BluetoothViewModel.shared.connectedToPurifier)
                    // Call this after to send locationTypes data
                    appState.sendLocationTypeIntervals()
                    
                    // Call this to fetch daily-records
                    DailyRecordViewModel.shared.fetchDailyRecords()
                    
                    // If after some delay and no health update is performed yet
                    // (lastPostTime more than REFRESH_IN_HOURS from now)
                    // Then, we call health update manually
                    DispatchQueue.main.asyncAfter(deadline: .now() + SECONDS_DELAY_TO_MANUALLY_QUERY_HEALTHKIT) {
                        // If appState.lastPostTime is nil, this won't do anything
                        if let lastPostTime = appState.lastPostTime {
                            Self.logger.notice("Last Post Time: \(lastPostTime, privacy: .public)")

                            let currentTime = Date()
                            let timeInterval = currentTime.timeIntervalSince(lastPostTime)
                            if timeInterval >= REFRESH_IN_HOURS * 3600 {
                                Self.logger.notice("Manually query HealthKit after \(SECONDS_DELAY_TO_MANUALLY_QUERY_HEALTHKIT, privacy: .public) seconds no automatic update")
                                HealthStore.shared.collectDataForAllTypes(isLongRunning: false)
                            }
                        }
                    }
                }

            case .background:
                return
            default:
                return
            }
        }
    }
}
