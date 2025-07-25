import SwiftUI

struct RegistrationView: View {
    @State private var pseudonym: String = ParticipantInfoModel.pseudonym ?? ""
    
    @State private var studyPeriods: [StudyPeriod] = []
    @State private var selectedStudyPeriod: StudyPeriod?
    
    @State private var purifiers: [Purifier] = []
    @State private var availablePurifiers: [Purifier] = []
    @State private var selectedPurifier: Purifier?
    
    @EnvironmentObject var appState: AppState
    
    @State private var isLoading: Bool = false
    
    // Fetch study periods and purifiers when the view is created
    private func loadStudyPeriods() {
        APIService.fetchStudyPeriods { result in
            switch result {
            case .success(let periods):
                DispatchQueue.main.async {
                    self.studyPeriods = periods
                    if let firstPeriod = periods.first {
                        self.selectedStudyPeriod = firstPeriod
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.appState.alertTitle = "Error"
                    self.appState.alertMessage = "Error loading study periods, try again"
                    self.appState.showAlert = true
                }
            }
        }
    }
    
    // Filter purifiers based on the selected study period
    private func filterAvailablePurifiers() {
        guard let selectedPeriod = selectedStudyPeriod else {
            self.selectedPurifier = nil
            return
        }
        self.availablePurifiers = self.purifiers.filter { purifier in
            purifier.availability.contains { $0.period_id == selectedPeriod.id && $0.is_available }
        }
        self.selectedPurifier = self.availablePurifiers.first
    }
    
    private func loadPurifiers() {
        APIService.fetchPurifiers { result in
            switch result {
            case .success(let fetchedPurifiers):
                DispatchQueue.main.async {
                    self.purifiers = fetchedPurifiers
                    self.filterAvailablePurifiers()
                }
            case .failure:
                DispatchQueue.main.async {
                    self.appState.alertTitle = "Error"
                    self.appState.alertMessage = "Error loading purifiers, try again"
                    self.appState.showAlert = true
                }
            }
        }
    }
    
    private func registerParticipant() {
        guard let sPeriod = selectedStudyPeriod else { return }
        guard let sPurifier = selectedPurifier else { return }
        
        isLoading = true
        
        APIService.registerParticipant(
            pseudonym: pseudonym.lowercased(),
            periodId: sPeriod.id,
            purifierId: sPurifier.id,
            notificationDeviceToken: appState.notificationDeviceToken
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    ParticipantInfoModel.pseudonym = pseudonym.lowercased()
                    ParticipantInfoModel.purifier = sPurifier
                    ParticipantInfoModel.studyPeriod = sPeriod
                    
                    appState.hasRegisteredParticipant = true
                    appState.alertTitle = "Registration Status"
                    appState.alertMessage = "Your pseudonym has been successfully registered ✅"
                    appState.showAlert = true
                case .failure(let error):
                    appState.alertTitle = "Registration Error ❌"
                    if let error = error as NSError? {
                        appState.alertMessage = error.userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
                    } else {
                        appState.alertMessage = error.localizedDescription
                    }
                    appState.showAlert = true
                }
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Title
                Text("Participant Info")
                    .font(.title.weight(.semibold))
                
                // Pseudonym Input
                VStack(alignment: .leading) {
                    Text("Participant pseudonym")
                        .font(.headline)
                        .textCase(.uppercase)
                    
                    TextField("Pseudonym", text: $pseudonym)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                        .cornerRadius(10)
                    
                    Text("This is the unique alphanumeric string assigned to you for the purpose of this study. It helps us securely and anonymously store your health data for data analysis.")
                        .font(.body)
                        .foregroundStyle(.gray)
                        .lineLimit(nil)
                }
                
                // Study Period Picker
                VStack(alignment: .leading) {
                    Text("Study Period")
                        .font(.headline)
                        .textCase(.uppercase)
                    
                    if !studyPeriods.isEmpty {
                        Picker("Study Period", selection: $selectedStudyPeriod) {
                            ForEach(studyPeriods, id: \.name) { period in
                                Text("\(period.name) (\(period.startDate.localDateString) - \(period.endDate.localDateString)")
                                    .tag(period as StudyPeriod?)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxHeight: 100)
                        .onChange(of: selectedStudyPeriod) { oldValue, newValue in
                            filterAvailablePurifiers()
                        }
                        .disabled(appState.hasRegisteredParticipant)
                    } else {
                        Text("Loading study periods...")
                            .foregroundStyle(.gray)
                    }
                }
                
                // Purifier Picker
                VStack(alignment: .leading) {
                    Text("Purifier Serial Number")
                        .font(.headline)
                        .textCase(.uppercase)
                    
                    if !purifiers.isEmpty {
                        Picker("Purifier Serial Number", selection: $selectedPurifier) {
                            ForEach(availablePurifiers) { purifier in
                                Text(purifier.name)
                                    .tag(purifier as Purifier?)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxHeight: 100)
                        .disabled(appState.hasRegisteredParticipant)
                    } else {
                        Text("Loading purifiers...")
                            .foregroundStyle(.gray)
                    }
                    
                    Text("Your purifier serial number (SN) can be found on the QR code tag behind the purifier. Only available purifiers for the selected period are shown.")
                        .font(.body)
                        .foregroundStyle(.gray)
                        .lineLimit(nil)
                }
                
                // Register Participant Button
                Button(action: {
                    if appState.hasRegisteredParticipant {
                        DispatchQueue.main.async{
                            appState.currentView = .pairing
                        }
                    } else {
                        registerParticipant()
                    }
                }) {
                    Group{
                        if isLoading {
                            ProgressView()
                        } else{
                            Text(appState.hasRegisteredParticipant ? "Next: Connect to Pufifier" : "Register Participant")
                                .font(.body.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(appState.hasRegisteredParticipant ? Color.green : (pseudonym.isEmpty || selectedPurifier == nil ? Color.gray : .accentColor))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(pseudonym.isEmpty || selectedPurifier == nil)
            }
            .padding()
        }.onAppear {
            loadStudyPeriods()
            loadPurifiers()
        }
    }
}
