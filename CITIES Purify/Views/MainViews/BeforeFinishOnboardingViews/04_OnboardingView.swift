import SwiftUI
import os

struct OnboardingView: View {
    @State private var currentPage = 0
    @EnvironmentObject var appState: AppState
    
    // Array of views for each onboarding step
    let onboardingSteps: [AnyView] = [
        AnyView(Onboarding_HealthKit_Permissions()),
        AnyView(Onboarding_Sleep_1()),
        AnyView(Onboarding_Sleep_2()),
        AnyView(Onboarding_Sleep_3()),
        AnyView(Onboarding_Charging()),
        AnyView(Onboarding_Blood_Oxygen()),
        AnyView(Onboarding_Daily_Survey()),
        AnyView(Onboarding_Daily_Survey_Example()),
        AnyView(Onboarding_Notification()),
        AnyView(Onboarding_Compensation()),
    ]
    
    var disableNextButton: Bool {
        (currentPage == 0 && !appState.hasAllowedHealthData) ||
        (currentPage == 8 && !appState.hasAllowedNotification)
    } // disable proceed button if these tasks aren't finished
    
    let BUTTON_SIZE = 50.0
    
    var body: some View {
        VStack(spacing: 0){
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingSteps.count, id: \.self) { index in
                    onboardingSteps[index]
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.top)
            
            HStack(spacing: 0) {
                // Previous Button: Only display if not on the first page
                    Button(action: {
                        if currentPage > 0 {
                            currentPage -= 1
                        }
                    }) {
                        Text("←")
                            .foregroundColor(.white)
                            .frame(width: BUTTON_SIZE, height: BUTTON_SIZE)
                            .background(Color.gray)
                            .clipShape(Circle())
                            
                    }
                    .padding()
                    .opacity(currentPage > 0 ? 0.5 : 0)
                    .disabled(currentPage <= 0)

                Spacer()
                
                // Progress Text
                    Text("Step \(currentPage + 1)/\(onboardingSteps.count)")
                        .font(.headline)
                        .foregroundColor(.gray)
                
                Spacer()

                // Next or "To App" Button
                Button(action: {
                    if currentPage < onboardingSteps.count - 1 {
                        currentPage += 1
                    } else {
                        appState.hasOnboarded = true
                        appState.currentView = .main
                        DailyRecordViewModel.shared.fetchDailyRecords(forceFetch: true)
                    }
                }) {
                    Text("→")
                        .foregroundColor(.white)
                        .frame(width: BUTTON_SIZE, height: BUTTON_SIZE) // Increase the size for better touch target
                        .background(currentPage < onboardingSteps.count - 1 ? Color.accentColor : Color.green)
                        .clipShape(Circle()) // Ensure circular shape
                }
                .padding()
                .disabled(disableNextButton)
            }

            
        }
    }
}


struct Onboarding_HealthKit_Permissions: View {
    let healthStore = HealthStore()
    @EnvironmentObject var appState: AppState
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Onboarding_HealthKit_Permissions.self)
    )
    
    var body: some View {
        OnboardingPageView(
            title: "Health Permissions",
            image: .single("StudyBanner"),
            content: AnyView(
                VStack(alignment: .leading) {
                    Text("""
                    Welcome to the study **Assessing the Health Impact of Indoor Air Purification Using Apple Watch Health Data**. 
                    
                    This is the research application that will allow us to collect your health data from the Apple Watch anonymously. 
                    """)
                    .padding(.bottom)
                    
                    // Check if permission has been granted through AppState
                    if appState.hasAllowedHealthData {
                        // If permission has already been granted
                        Text("Access to health data from Apple Watch already granted.")
                            .foregroundColor(.green)
                    } else {
                        // If permission has not been granted yet
                        VStack(alignment: .leading) {
                            Text("Click **GRANT PERMISSION** to grant the application necessary permission to anonymously collect health data")
                            
                            Button(action: {
                                // Request HealthKit authorization
                                HealthStore.shared.requestAuthorization { success in
                                    if success {
                                        Self.logger.notice("HealthKit authorization successful!")

                                        // Start long-running queries for all types
                                        HealthStore.shared.collectDataForAllTypes(isLongRunning: true)
                                        
                                        // Enable background delivery for all types
                                        HealthStore.shared.enableBackgroundDeliveryForAllTypes()
                                        
                                        // Use AppState to persist the permission granted
                                        DispatchQueue.main.async{
                                            appState.hasAllowedHealthData = true
                                        }
                                    } else {
                                        Self.logger.error("HealthKit authorization failed.")
                                    }
                                }
                            }) {
                                Text("GRANT PERMISSION")
                                    .font(.body.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            )
        )
    }
}

struct Onboarding_Sleep_1: View {
    var body: some View {
        OnboardingPageView(
            title: "Set Up Sleep Tracking",
            image: .multiple(["SleepSchedule1","SleepSchedule2","SleepSchedule3"]) ,
            content: AnyView(
                VStack(alignment: .leading) {
                    Text("""
                    1. Open **Health app** on your iPhone and **Set Up Sleep** (if you haven't done so already)
                    
                    2. Set up sleep schedule with your preferred **Sleep Goals** and **Bedtime and Wake Up times**. This is so that the Watch can be put automatically in **Sleep Focus** every night to allow sleep tracking to work. Without **Sleep Focus** turned on, sleep tracking will not track the different stages of sleep.
                    
                    3. You can customize the schedule however you like. For example, in the weekend, you can set the wake time to be later than weekday's. 
                    
                    4. It's better to overestimate the sleep schedule than underestimate it. The Watch is smart enough to detect when you get up earlier than the schedule, for example. We understand that your actual sleep schedule might vary day-to-day.
                    
                    **Guide:** [support.apple.com/en-us/108906](https://support.apple.com/en-us/108906)
                    
                    **Guide**: [support.apple.com/guide/watch/track-your-sleep-apd830528336/watchos](https://support.apple.com/guide/watch/track-your-sleep-apd830528336/watchos)
                    """)
                }
            )
        )
    }
}

struct Onboarding_Sleep_2: View {
    var body: some View {
        OnboardingPageView(
            title: "Sleep Tracking (Watch)",
            image: .multiple(["SleepWatchApp1","SleepWatchApp2"]) ,
            content: AnyView(
                VStack(alignment: .leading) {
                    Text("""
                    1. Open the **Watch app**, click **Sleep**, and toggle on sleep tracking for this Apple Watch
                    
                    2. **[IMPORTANT]** Make sure Charging Reminders is on, so your Watch notify you to charge before bedtime if the battery level is < 30% 
                    """)
                }
            )
        )
    }
}

struct Onboarding_Sleep_3: View {
    var body: some View {
        OnboardingPageView(
            title: "Sleep Focus",
            image: .multiple(["SleepFocus1","SleepFocus2","SleepFocus3"]),
            content: AnyView(
                VStack(alignment: .leading) {
                    Text("""
                    If you sleep outside of the scheduled time, you can also manually put your Watch in **Sleep Focus** by clicking the side button and choose the 🌙 icon.
                    """)
                }
            )
        )
    }
}

struct Onboarding_Charging: View {
    var body: some View {
        OnboardingPageView(
            title: "Remember to Charge",
            image: .single("Charging"),
            content: AnyView(
                ScrollView{
                    Text("30%")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.green)
                        .multilineTextAlignment(.center)
                    Text("""
                    The Watch's **Charging Reminders** will notify you if you don't have above 30% battery before going to bed. A 30-min charge every day should be enough, for example, when you take a shower. 
                    """)
                }
            )
        )
    }
}

struct Onboarding_Blood_Oxygen: View {
    var body: some View {
        OnboardingPageView(
            title: "Set Up Blood Oxygen",
            image: .multiple(["BloodOxygenScreenshot1", "BloodOxygenScreenshot2"]),
            content: AnyView(
                ScrollView{
                    Text("""
                    1. Open Watch app on your iPhone
                    2. Click on Blood Oxygen app
                    3. Turn on (if haven't already)
                    4. **[IMPORTANT]** Allow background measurements in **Sleep Focus** and in **Theater Mode**
                    
                    **Guide:** [support.apple.com/en-us/120358](https://support.apple.com/en-us/120358)
                    """)
                }
            )
        )
    }
}

struct Onboarding_Daily_Survey: View {
    var body: some View {
        OnboardingPageView(
            title: "Daily Survey",
            image: .single("DailySurvey"),
            content: AnyView(
                VStack(alignment: .leading) {
                    Text("""
                    **Don't forget** to fill out the daily 2-min survey about the **3 types of locations** you were in during the previous day: at home, indoors somewhere else, or outdoors.
                    
                    You'll receive **a push notification at \(SURVEY_AVAILABLE_AT)** to let you know that the survey for today is available. Each survey is only available for \(SURVEY_AVAILABLE_FOR), so remember to submit on time.
                    """)
                }
            )
        )
    }
}

struct Onboarding_Daily_Survey_Example: View {
    @State private var sampleUrl = Config.surveyEndpoint(
        pseudonym: ParticipantInfoModel.pseudonym ?? "",
        dateString: "2025-01-02",
        isSample: true
    )
    
    @State private var isLoading = true
    
    var body: some View {
        VStack{
            Text("Try Out a Sample Survey")
                .font(.title3.weight(.bold))
            
            ZStack{
                WebView(url: $sampleUrl, isLoading: Binding($isLoading)).frame(minHeight: 500)
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct Onboarding_Notification: View {
    @EnvironmentObject var appState: AppState
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Onboarding_Notification.self)
    )

    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                DispatchQueue.main.async {
                    if granted {
                        appState.hasAllowedNotification = true
                        
                        // Register for remote notifications immediately after permission is granted
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        appState.hasAllowedNotification = false
                    }
                }
            } catch {
                Self.logger.error("Error requesting notification permission: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    appState.hasAllowedNotification = false
                }
            }
            
            DispatchQueue.main.async {
                appState.hasAskedForNotificationPermissionBefore = true
            }
        }

    }
    
    private func notificationStatus( completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { (settings) in
            let authorized = settings.authorizationStatus == .authorized
            completion(authorized)
        }
    }
    
    var body: some View {
        OnboardingPageView(
            title: "Notification Permission",
            image: .none,
            content: AnyView(
                VStack(alignment: .leading) {
                    Text("""
                    **IMPORTANT:** Allowing notification is crucial to the success of the study. We will only notify you once a day to let you know that the daily survey is available to fill out, or if you forget to track your sleep or fill out the daily survey for an extended amount of time.

                    You'll receive **a push notification reminder** if \(NUM_DAYS_TO_SEND_NOTI) consecutive surveys or sleep trackings haven't been completed. If you tracked sleep but still received the sleep reminder notification, it is because you haven't opened the app occasionally to sync data. Open it and you will see the updated info. Click **Force Sync Data** if you still see no data in the app. 

                    You'll receive **an email reminder** if \(DAYS_TO_SEND_EMAILS) consecutive surveys or sleep trackings haven't been completed.
                    
                    Your consistency matters a lot because we need a large number of data points to see meaningful correlations between air quality and its health impact.
                    """)
                    
                    if appState.hasAllowedNotification {
                        Text("Notification permissions granted!")
                            .foregroundColor(.green)
                    } else {
                        if appState.hasAskedForNotificationPermissionBefore {
                            Text("""
                        Because you previously denied notification permission, please by click the button below to enable notifications in the **Settings app** 
                        """)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.top)
                            
                            Button(action: {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            }, label: {
                                Text("To Settings App")
                                    .font(.body.weight(.bold))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            })
                            
                        } else{
                            Button(action: {
                                requestNotificationPermission()
                            }) {
                                Text("GRANT PERMISSION")
                                    .font(.body.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
            )
        )
    }
}


struct Onboarding_Compensation: View {
    var body: some View {
        OnboardingPageView(
            title: "Study Compensation",
            image: .none,
            content: AnyView(
                ScrollView{
                    Text("""
                    We would like to remind you of the compensation here.
                    
                    A compensation of **up to 350 AED** will be provided after the purification period. The total amount is calculated as follows: 
                    
                    - **Base compensation for simply participating in the study:** 70 AED 
                    - **Additional reward for sleep tracking:** Up to 140 AED, pro-rated based on the number of nights tracked over the 5-week study (35 nights)
                    - **Additional reward for daily 2-minute surveys:** Up to 140 AED, pro-rated based on the number of surveys completed over the 5-week study (35 surveys)
                    
                    *The total compensation will be the sum of the three components listed above, rounded to the nearest 10 AED.*
                    
                    If you decide to withdraw before the study is completed, your compensation will include the base compensation (70 AED) and pro-rated additional rewards for the tasks completed.
                    """)
                }
            )
        )
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(mockAppState)
    }
    
    // Mock AppState for preview purposes
    static var mockAppState: AppState {
        let state = AppState()
        state.hasOnboarded = false
        state.currentView = .onboarding
        return state
    }
}
