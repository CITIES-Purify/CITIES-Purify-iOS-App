import SwiftUI

struct ParticipantStatusView: View {
    let displaySyncButton: Bool
    @State private var pseudonym: String? = ParticipantInfoModel.pseudonym
    @State private var purifierName: String? = ParticipantInfoModel.purifier?.name
    
    @State private var selectedStudyPeriod: StudyPeriod? = ParticipantInfoModel.studyPeriod
    @StateObject private var dailyRecordViewModel = DailyRecordViewModel.shared
    
    @StateObject private var bluetoothViewManager = BluetoothViewModel.shared
    
    private var totalCurrentReward: String {
        if let base = dailyRecordViewModel.dailyRecordsResponse?.base_compensation,
           let sleep = dailyRecordViewModel.dailyRecordsResponse?.records["sleep"]?.current_reward,
           let survey = dailyRecordViewModel.dailyRecordsResponse?.records["survey"]?.current_reward{
            return String(base + sleep + survey)
        } else {
            return "--"
        }
    }
    
    private var maxReward: String {
        if let base = dailyRecordViewModel.dailyRecordsResponse?.base_compensation,
           let sleep = dailyRecordViewModel.dailyRecordsResponse?.records["sleep"]?.max_reward,
           let survey = dailyRecordViewModel.dailyRecordsResponse?.records["survey"]?.max_reward{
            return String(base + sleep + survey)
        } else {
            return "--"
        }
    }
    
    var body: some View {
        Section(
            header: Text("Study Overview")
        ) {
            // Pseudonym
            HStack {
                Text("Pseudonym")
                Spacer()
                Text(pseudonym ?? "--").foregroundStyle(.gray)
            }
            
            // Purifier name
            HStack {
                Text("Purifier")
                Spacer()
                Text(purifierName ?? "--").foregroundStyle(.gray)
            }
            
            // Study Period
            if let studyPeriod = selectedStudyPeriod {
                HStack {
                    Text(studyPeriod.name)
                    Spacer()
                    Text("\(formatDate(studyPeriod.startDate)) - \(formatDate(studyPeriod.endDate))").foregroundStyle(.gray)
                }
                
                HStack {
                    Text("Today")
                    Spacer()
                    Text(getWeekAndDay(studyPeriod: studyPeriod)).foregroundStyle(.gray)
                }
            } else {
                HStack {
                    Text("Study Period").foregroundStyle(.gray)
                    Spacer()
                    Text("--")
                }
            }
            
            // Current Reward
            HStack {
                Text("Current Reward")
                Spacer()
                Text("AED \(totalCurrentReward) / \(maxReward)").foregroundStyle(.gray)
            }
            
            // Purifier Status
            HStack {
                Text("Purifier Status")
                Spacer()
                
                ProgressView()
                    .controlSize(.mini)
                    .padding(0)
                    .opacity(bluetoothViewManager.connectingToPurifier || bluetoothViewManager.pairingToPurifier ? 1 : 0)
                Text(
                    bluetoothViewManager.connectedToPurifier ?
                    (bluetoothViewManager.pairingToPurifier ? "Pairing"
                     : (bluetoothViewManager.pairedToPurifier ? "Paired" : "In range, not paired")
                    )
                    : "Not in range"
                )
                .foregroundStyle(
                    bluetoothViewManager.connectedToPurifier ?
                    (bluetoothViewManager.pairingToPurifier ? .yellow
                     : (bluetoothViewManager.pairedToPurifier ? .green : .yellow)
                    )
                    : .red
                )
            }
            
            // Force Sync Button
            if displaySyncButton {
                ForceSyncButton()
            }
        }
    }
}

// Helper function to calculate the current week and day based on the current date
func getWeekAndDay(studyPeriod: StudyPeriod) -> String {
    let currentDate = Date()
    let calendar = Calendar.current
    
    // Check if current date is before or after the study period
    if currentDate < studyPeriod.startDate {
        let daysUntilStart = calendar.dateComponents([.day], from: currentDate, to: studyPeriod.startDate).day ?? 0
        return "\(daysUntilStart)d until start"
    } else if currentDate > studyPeriod.endDate {
        let daysSinceEnd = calendar.dateComponents([.day], from: studyPeriod.endDate, to: currentDate).day ?? 0
        return "The study ended \(daysSinceEnd)d ago"
    }
    
    // Calculate the number of weeks since the start of the study period
    let startDate = studyPeriod.startDate
    let daysBetween = calendar.dateComponents([.day], from: startDate, to: currentDate).day ?? 0
    let week = (daysBetween / 7) + 1 // Calculate week number (1-based)
    let day = daysBetween % 7 + 1 // Calculate day of the week (1-based)
    
    // Format the date
    let formattedDate = formatDate(currentDate)
    return "\(formattedDate) (Week \(week) Day \(day))"
}

// Helper function to format dates
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter.string(from: date)
}

