import SwiftUI

struct PairingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bluetoothViewModel = BluetoothViewModel.shared
    
    @State var allowedToSkipPairing: Bool = false
    
    @State private var purifierID: String? = ParticipantInfoModel.purifier?.id
    @State private var purifierBleUUID: String? = ParticipantInfoModel.purifier?.ble_uuid
    @State private var purifierAlias: String? = ParticipantInfoModel.purifier?.alias

    private func toNextView() {
        if appState.hasOnboarded{
            appState.currentView = .main
        } else{
            appState.currentView = .onboarding
        }
    }
    
    private var buttonLabel: String {
        return appState.hasPairedPurifier ?
            (appState.hasOnboarded ? "Home" : "To Onboarding!")
            : "Pair Purifier"
    }
    
    var body: some View {
        NavigationView{
            List{
                ParticipantStatusView(displaySyncButton: false).padding(0)
                
                // Pair Purifier Button (Visible only after registration)
                Section{
                    Button(action: {
                        if appState.hasPairedPurifier {
                            toNextView()
                        } else {
                            bluetoothViewModel.scanAllDevices()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                                if !bluetoothViewModel.connectedToPurifier{
                                    self.allowedToSkipPairing = true
                                }
                            }
                        }
                    }) {
                        Group{
                            if bluetoothViewModel.connectingToPurifier || bluetoothViewModel.pairingToPurifier {
                                ProgressView()
                            } else{
                                Text(buttonLabel)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .font(.body.weight(.bold))
                    }
                }
                
                // Add a button to skip pairing if it doesn't work,
                // or if there is not enough information about the purifier
                if (self.allowedToSkipPairing){
                    Section{
                        Button(action: {
                            toNextView()
                        }) {
                            Text("Purifier not found? Skip pairing purifier")
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }.listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Connect to Purifier")
            .frame(maxWidth: .infinity, maxHeight:.infinity)
            .onChange(of: bluetoothViewModel.pairedToPurifier) { _, newValue in
                if newValue == true {
                    DispatchQueue.main.async {
                        appState.hasPairedPurifier = true
                    }
                }
            }
        }
        .onAppear() {
            // Fetch ble_uuid and alias from server if they don't exist yet
            if let id = purifierID, purifierBleUUID == nil || purifierAlias == nil {                APIService.fetchPurifierWithID(id: id) { result in
                    switch result {
                    case .success(let fetchedPurifier):
                        DispatchQueue.main.async {
                            ParticipantInfoModel.purifier = fetchedPurifier
                        }
                    case .failure:
                        DispatchQueue.main.async {
                            self.appState.alertTitle = "Error"
                            self.appState.alertMessage = "Error loading purifier, contact research personnel"
                            self.appState.showAlert = true
                        }
                    }
                }
            }
        }
    }
}
