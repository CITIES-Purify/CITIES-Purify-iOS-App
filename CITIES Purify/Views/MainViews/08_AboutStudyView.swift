import SwiftUI
import WebKit

struct AboutStudyView: View {
    @EnvironmentObject var appState: AppState
    @State private var consentFormUrl = "https://docs.google.com/forms/d/e/1FAIpQLScy3Jl6KbuaJPi4QRozzWL6R_gS7rGnTXDjVGRSV-HT5TFFDg/viewform"
    
    @State private var showPasswordSheet = false
    @State private var password = ""
    @State private var isPasswordIncorrect = false
    
    var body: some View {
        List {
            // Description Section
            Section(footer: Text("Still have questions? Contact the study team!")) {
                Text("""
             The objective of this intervention study is to examine the health impact of indoor air purification using health data obtained from your own Apple Watch.
                        
             **CITIES Purify** is the iOS application that **securely** and **anonymously** collects said health data for the study.
             
             The study lasts 5 weeks. You can see the study period and current compensation information in the **Home** view.
                        
             See the unsigned consent form below for more information about all aspects of the study.
             """)
                .foregroundColor(.gray)
                .padding(.vertical, 8)
            }
            
            Section {
                NavigationLink("See Consent Form Again") {
                    WebView(url: $consentFormUrl)
                        .navigationTitle("Consent Form")
                        .navigationBarTitleDisplayMode(.inline)
                }
                
                NavigationLink("Contact Us") {
                    ContactView()
                }
            }
            
            Section {
                Button(action: {
                    DispatchQueue.main.async {
                        appState.currentView = .onboarding
                    }
                }) {
                    Text("Start Onboarding Tutorial Again")
                        .foregroundColor(.blue)
                }
            }
            
            if (!appState.hasPairedPurifier || BluetoothPeripheral.discoveredPeripheral == nil) {
                Section {
                    Button(action: {
                        showPasswordSheet = true
                    }) {
                        Text("Pair Purifier")
                            .foregroundColor(.blue)
                    }
                }
                .sheet(isPresented: $showPasswordSheet) {
                    PasswordPromptView(password: $password, isPasswordIncorrect: $isPasswordIncorrect, onConfirm: {
                        if password.lowercased() == "cleanair" {
                            DispatchQueue.main.async {
                                if (ParticipantInfoModel.purifier?.ble_uuid == nil || ParticipantInfoModel.purifier?.alias == nil){
                                    appState.hasPairedPurifier = false
                                    BluetoothViewModel.shared.initCentralManager()
                                    appState.currentView = .pairing
                                }
                            }
                            showPasswordSheet = false // Dismiss the sheet
                        } else {
                            isPasswordIncorrect = true
                        }
                    }, onCancel: {
                        password = ""
                        showPasswordSheet = false
                    })
                }
            }
        }.navigationTitle("About Study")
    }
}

// Separate View for Password Prompt
struct PasswordPromptView: View {
    @Binding var password: String
    @Binding var isPasswordIncorrect: Bool
    var onConfirm: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Password")
                .font(.headline)
            
            TextField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            if isPasswordIncorrect {
                Text("Incorrect password. Try again.")
                    .foregroundColor(.red)
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .padding()
                
                Button("Confirm") {
                    onConfirm()
                }
                .padding()
                .background(.accent)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}
