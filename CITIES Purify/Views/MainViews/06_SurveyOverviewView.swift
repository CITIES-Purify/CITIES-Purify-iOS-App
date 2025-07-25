import SwiftUI

struct SurveyOverviewView: View {
    @State private var studyPeriod: StudyPeriod = ParticipantInfoModel.studyPeriod!
    @ObservedObject private var dailyRecordViewModel = DailyRecordViewModel.shared
    
    @State private var showWebView: Bool = false
    @State private var selectedSurveyURL: String = ""
    
    private var pendingDaysCount: Int {
        dailyRecordViewModel.dailyRecordsResponse?.records["survey"]?.num_pending_days ?? 0
    }
    
    var body: some View {
        Form {
            Section(
                header: HStack {
                    Text("Pending Survey (\(pendingDaysCount))")
                    Spacer()
                    pendingDaysCount > 0 ? Text("Expires In") : nil
                },
                footer: pendingDaysCount > 0 ? Text("New survey at \(SURVEY_AVAILABLE_AT) every day") : nil
            ) {
                if let sampleTypeData = dailyRecordViewModel.dailyRecordsResponse?.records["survey"] {
                    if pendingDaysCount <= 0 {
                        Text("New survey at \(SURVEY_AVAILABLE_AT) every day.")
                    } else {
                        ForEach(sampleTypeData.daily_records.filter {
                            ($0.is_pending ?? false) && !$0.is_tracked
                        }, id: \.day_of_study) { record in
                            Button(action: {
                                // Set the URL and show the WebView
                                DispatchQueue.main.async {
                                    selectedSurveyURL = Config.surveyEndpoint(
                                        pseudonym: ParticipantInfoModel.pseudonym ?? "",
                                        dateString: record.date
                                    )
                                    showWebView = true
                                }
                            }) {
                                HStack {
                                    Text(record.date)
                                    Spacer()
                                    if let duesInHours = record.dues_in_hours {
                                        Text("\(duesInHours / 24)d \(duesInHours % 24)h")
                                            .font(.caption.weight(.medium))
                                            .padding(6)
                                            .background(Color.yellow)
                                            .cornerRadius(8)
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            SampleTypeTrackingView(
                sampleTypeId: "survey",
                title: "Daily Survey",
                explanationHeader: Text("Why complete the daily survey?"),
                explanationContent: Text("""
                                                    To estimate your PM2.5 exposure based on the type of locations you were in. This helps us **anonymously** analyze how PM2.5 levels may affect health data.
                                                    """),
                explanationFooter: Text("""
                                                            It takes 2 minutes! It does **NOT** capture your precise locations. Only 3 types: at home, indoors somewhere else, and outdoors
                                                            """),
                textForLinkToGuie: "See Daily Survey Guide Again",
                onboardingViews: [
                    AnyView(Onboarding_Daily_Survey()),
                    AnyView(Onboarding_Daily_Survey_Example()),
                ],
                trackingProgressHeader: Text("Daily Survey Progress by Week"),
                trackingProgressFooter: Text("""
                                            This chart summarizes which dates CITIES Purify receives your daily survey answers.
                                            """)
            )
        }
        .fullScreenCover(isPresented: $showWebView) {
            SurveyWebContainer(url: $selectedSurveyURL, onSurveyComplete: {
                showWebView = false // Dismiss WebView when survey is complete
                
                // fetch again daily record after a survey is completed
                dailyRecordViewModel.fetchDailyRecords(forceFetch: true)
            }).interactiveDismissDisabled()
        }
    }
}

struct SurveyWebContainer: View {
    @Binding var url: String
    @State private var isLoading = true
    var onSurveyComplete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showExitWarning = false
    
    var body: some View {
        NavigationStack {
            ZStack{
                WebView(url: $url, isLoading: Binding($isLoading), onSurveyComplete: {
                    onSurveyComplete?()
                    dismiss()
                })
                if isLoading {
                    ProgressView()
                }
            }
            .edgesIgnoringSafeArea(.all)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showExitWarning = true
                    } label: {
                        Label("Back", systemImage: "arrow.left")
                    }
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("Unsaved Changes", isPresented: $showExitWarning) {
                Button("Leave Anyway", role: .destructive) {
                    dismiss()
                }
                Button("Continue Filling Out Survey", role: .cancel) {}
            } message: {
                Text("You have unsaved progress")
            }
        }
    }
}
