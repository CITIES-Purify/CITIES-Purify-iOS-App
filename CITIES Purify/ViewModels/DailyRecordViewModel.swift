import Foundation
import UserNotifications

class DailyRecordViewModel: ObservableObject {
    static let shared = DailyRecordViewModel()
        
    @Published var dailyRecordsResponse: DailyRecordsResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var dataLoaded: Bool = false
    
    private var lastFetchTime: Date?
    
    func fetchDailyRecords(forceFetch:Bool = false) {
        if (!forceFetch) {
            self.checkDataExpiry()
            
            if self.isLoading || self.dataLoaded {
                return
            }
        } else{
            if self.isLoading {
                return
            }
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        DispatchQueue.main.async{
            AppState.shared.queuedRequests += 1
            AppState.shared.syncingTotalRequests += 1
        }
        
        guard let pseudonym = ParticipantInfoModel.pseudonym else {
            self.errorMessage = "Participant pseudonym is missing."
            self.isLoading = false
            return
        }
        
        APIService.fetchDailyRecords(pseudonym: pseudonym) { result in
            DispatchQueue.main.async {
                AppState.shared.queuedRequests -= 1

                switch result {
                case .success(let response):
                    self.dailyRecordsResponse = response
                    self.dataLoaded = true

                    // Extract the badge count
                    let badgeCount = response.records["survey"]?.num_pending_days ?? 0

                    // Set the badge count
                    UNUserNotificationCenter.current().setBadgeCount(badgeCount)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                
                self.isLoading = false
                self.lastFetchTime = Date()
                self.dataLoaded = true
            }
        }
    }
    
    func checkDataExpiry() {
        guard let fetchTime = lastFetchTime else {
            self.dataLoaded = false
            return
        }
        
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(fetchTime)
        
        if timeInterval >= REFRESH_IN_HOURS * 3600 {
            self.dataLoaded = false
            self.lastFetchTime = nil
        }
    }
}
