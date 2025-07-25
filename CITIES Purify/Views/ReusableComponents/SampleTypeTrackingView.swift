import SwiftUI

struct SampleTypeTrackingView: View {
    @State private var studyPeriod: StudyPeriod = ParticipantInfoModel.studyPeriod!
    @ObservedObject private var dailyRecordViewModel = DailyRecordViewModel.shared
    
    let sampleTypeId: String
    let title: String
    
    let explanationHeader: Text
    let explanationContent: Text
    let explanationFooter: Text
    let textForLinkToGuie: String
    let onboardingViews: [AnyView]
    
    let trackingProgressHeader: Text
    let trackingProgressFooter: Text
    
    private let trackedLabel = "✅ Tracked "
    private let pendingLabel = "⚠️ Pending (still fillable)"
    private let missedLabel = "❌ Missed"
    private let rewardLabel = "💰 Reward"
    
    var body: some View {
        List {
            // MARK: EXPLANATION
            Section(
                header: explanationHeader,
                footer: explanationFooter
            ) {
                explanationContent
                
                NavigationLink(textForLinkToGuie) {
                    ScrollView {
                        ForEach(0..<onboardingViews.count, id: \.self) { index in
                            onboardingViews[index]
                        }
                    }
                }
            }
            
            // MARK: TRACKING PROGRESS
            Section(
                header: trackingProgressHeader,
                footer: trackingProgressFooter
            ) {
                // Graph
                if dailyRecordViewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = dailyRecordViewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                } else {
                    if let message = dailyRecordViewModel.dailyRecordsResponse?.message {
                        Text(message)
                    }
                    
                    if let sampleTypeData = dailyRecordViewModel.dailyRecordsResponse?.records[sampleTypeId] {
                        if !sampleTypeData.daily_records.isEmpty {
                            SampleTypeTrackingGraphView(
                                numTotalDays: sampleTypeData.num_total_days ?? 0,
                                dailyRecords: sampleTypeData.daily_records
                            )
                        }
                        
                        HStack {
                            Text(trackedLabel)
                            Spacer()
                            if let trackedDays = sampleTypeData.num_tracked_days, let totalDays = sampleTypeData.num_total_days {
                                Text("\(trackedDays) / \(totalDays)")
                            } else {
                                Text("-- / --")
                            }
                        }
                        
                        if let pendingDays = sampleTypeData.num_pending_days{
                            HStack {
                                Text(pendingLabel)
                                Spacer()
                                Text("\(pendingDays)")
                            }
                        }

                        HStack {
                            Text(missedLabel)
                            Spacer()
                            if let missedDays = sampleTypeData.num_missed_days {
                                Text("\(missedDays)")
                            } else {
                                Text("--")
                            }
                        }
                        
                        HStack {
                            Text(rewardLabel)
                            Spacer()
                            if let reward = sampleTypeData.current_reward, let maxReward = sampleTypeData.max_reward {
                                Text("AED \(reward) / \(maxReward)")
                            } else if let maxReward = sampleTypeData.max_reward {
                                Text("AED -- / \(maxReward)")
                            } else {
                                Text("AED -- / --")
                            }
                        }
                        
                        ForceSyncButton()
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

struct SampleTypeTrackingGraphView: View {
    let numTotalDays: Int
    let dailyRecords: [DailyRecord]
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<numTotalDays / 7 + (numTotalDays % 7 == 0 ? 0 : 1), id: \.self) { weekIndex in
                let weekStartDay = weekIndex * 7 + 1
                let daysInWeek = min(7, numTotalDays - weekStartDay + 1)
                
                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        ForEach(0..<daysInWeek, id: \.self) { dayIndex in
                            let day_of_study = weekStartDay + dayIndex
                            let fillColor = getFillColor(for: day_of_study)
                            
                            Rectangle()
                                .fill(fillColor)
                                .frame(height: 50)
                                .cornerRadius(5)
                        }
                    }
                    Text("W\(weekIndex + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func getFillColor(for dayOfStudy: Int) -> Color {
        guard let dailyRecord = dailyRecords.first(where: { $0.day_of_study == dayOfStudy }) else {
            return Color.gray.opacity(0.5)
        }
        
        // is_pending optional, default to false, but if true, return .yellow
        if dailyRecord.is_pending ?? false {
            return .yellow
        }
        
        if dailyRecord.is_tracked {
            return .green
        }
        
        return .red
    }
}
