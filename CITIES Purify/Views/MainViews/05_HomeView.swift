import SwiftUI

struct HomeView: View {
    @State private var pseudonym: String? = ParticipantInfoModel.pseudonym
    @State private var selectedStudyPeriod: StudyPeriod? = ParticipantInfoModel.studyPeriod
    @StateObject private var dailyRecordViewModel = DailyRecordViewModel.shared
    
    private var numPendingSurveys: Int? {
        return self.dailyRecordViewModel.dailyRecordsResponse?.records["survey"]?.num_pending_days
    }
    
    private var surveyAvailableAt: Text = Text("\(SURVEY_AVAILABLE_AT)").foregroundColor(.accent)
        .font(.body.weight(.bold))

    private var SubtitleSurveyText: Text {
        if let numPending = numPendingSurveys {
            if (numPending > 0){
                return Text("Expiring soon! There \(numPending > 1 ? "are" : "is") ")
                + Text("\(numPending)")
                    .foregroundColor(.red)
                    .font(.body.weight(.bold))
                + Text(" pending survey\(numPending > 1 ? "s" : "") to fill out")
            } else {
                return Text("No survey pending 🙌. New survey available at ") + surveyAvailableAt
            }
        } else {
            return Text("New survey available at ") + surveyAvailableAt
        }
    }
    
    private var subtitleSleep: String {
        if let sleepRecords = dailyRecordViewModel.dailyRecordsResponse?.records["sleep"] {
            if let lastSleepRecord = sleepRecords.daily_records.last {
                if lastSleepRecord.is_tracked {
                    return "You tracked last night sleep, congrats 😄"
                } else {
                    return "The app didn't receive your sleep data last night 🥲"
                }
            }
            else {
                return "Don't forget to wear the Watch to sleep for bonus compensation 🤑"
            }
        } else {
            return "Don't forget to wear the Watch to sleep for bonus compensation 🤑"
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ParticipantStatusView(displaySyncButton: true)
                
                Section(header: Text("Check Here Every Day")){
                    NavigationLink(destination: SurveyOverviewView()) {
                        NavigationCard(
                            title: "Daily Survey ✍️",
                            subtitle: SubtitleSurveyText,
                            titleColor: .accent
                        ).frame(maxHeight: .infinity)
                    }
                    
                    NavigationLink(destination: SleepTrackingView()) {
                        NavigationCard(
                            title: "Sleep Tracking 😴",
                            subtitle: Text(subtitleSleep),
                            titleColor: .purple
                        ).frame(maxHeight: .infinity)
                    }
                    
                    NavigationLink(destination: AboutStudyView()) {
                        NavigationCard(
                            title: "About Study 🤨",
                            subtitle: Text("In doubt? Click here to read the details of the study again or to contact the researchers."),
                            titleColor: .orange
                        )
                    }
                }
            }
            .navigationTitle("Home")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(mockAppState)
    }
    
    // Mock AppState for preview purposes
    static var mockAppState: AppState {
        let state = AppState()
        state.hasOnboarded = true
        state.currentView = .main
        return state
    }
}
