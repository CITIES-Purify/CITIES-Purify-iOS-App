import HealthKit
import os
import UserNotifications

class HealthStore {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: HealthStore.self)
    )
    
    static let shared = HealthStore()
    
    let hkHealthStore = HKHealthStore()
    
    // MARK: - Background Delivery for All Types
    // TODO: completion handler must be done asap when background mode is run
    // https://stackoverflow.com/questions/36326796/hkobserverquerycompletionhandler-timeout
    // or use background task
    // https://swiftwithmajid.com/2022/07/06/background-tasks-in-swiftui/
    func enableBackgroundDeliveryForAllTypes() {
        var logMessages: [String] = []

        for sampleType in typesToRead {
            hkHealthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
                if success {
                    logMessages.append("\(sampleType.identifier)")
                } else {
                    logMessages.append("\(sampleType.identifier): \(String(describing: error))")
                }

                // Ensure logging happens after all iterations
                if logMessages.count == typesToRead.count {
                    Self.logger.notice("Background Delivery Results: \(logMessages.joined(separator: " | "), privacy: .public)")
                }
            }
        }
    }

    // MARK: - Start Queries for All Types
    // This method can't be used in background with observer query because it is called one by one per sampleType --> can't aggregate all and send to server
    // Alternative: save in local DB, then push to backend
    func collectDataForAllTypes(isLongRunning: Bool) {
        for type in typesToRead {
            startQuery(for: type, isLongRunning: isLongRunning) { samples, deletedObjects, queryAnchorOrNil in
                
                Self.logger.notice(
                    "Type: \(type, privacy: .public), Samples: \(samples.count < 10 ? "\(samples)" : "\(samples.count) (counts)", privacy: .public)"
                )
                
                guard let pseudonym = ParticipantInfoModel.pseudonym else {
                    return
                }
                
                let samplesUrl = Config.samplesEndpoint(pseudonym: pseudonym)
                
                // MARK: DELETE first
                if !deletedObjects.isEmpty {
                    DispatchQueue.main.async {
                        AppState.shared.queuedRequests += 1
                        AppState.shared.syncingTotalRequests += 1
                    }
                    
                    let formattedDeletedObjects: [[String: String?]] = deletedObjects.map {
                        [
                            "id": $0.uuid.uuidString,
                            "stid": sampleTypeToBackendMapping[type] ?? nil
                        ]
                    }
                    
                    APIService.modifySamples(to: samplesUrl, with: formattedDeletedObjects, method: HTTPMethod.delete, description: sampleTypeToBackendMapping[type] ?? ""){success in
                        DispatchQueue.main.async {
                            AppState.shared.queuedRequests -= 1
                        }
                    }
                }
                
                // MARK: Main POST for /samples
                // Filter samples before processing
                // Only retain samples from the Apple Watch
                let filteredSamples = samples.filter { sample in
                    let productType = sample.sourceRevision.productType ?? ""
                    let bundleIdentifier = sample.sourceRevision.source.bundleIdentifier
                    return productType.contains(WATCH_SUBSTRING) && bundleIdentifier.contains(COM_APPLE)
                }
                if !filteredSamples.isEmpty {
                    let formattedSamples: [HealthData] = filteredSamples.map { self.formatSampleToPost($0) }
                    
                    DispatchQueue.main.async {
                        AppState.shared.queuedRequests += 1
                        AppState.shared.syncingTotalRequests += 1
                    }
                    
                    APIService.modifySamples(to: samplesUrl, with: formattedSamples, method: HTTPMethod.post, description: sampleTypeToBackendMapping[type] ?? ""){ success in
                        DispatchQueue.main.async {
                            AppState.shared.queuedRequests -= 1
                        }
                        
                        // If the POST is success, save the new queryAnchor
                        // (or else, we risk losing data because new queryAnchor is saved but server hasn't received data)
                        if success == true, let queryAnchor = queryAnchorOrNil {
                            do {
                                let archivedData = try NSKeyedArchiver.archivedData(withRootObject: queryAnchor, requiringSecureCoding: true)
                                UserDefaults.standard.setValue(archivedData, forKey: generateAnchorKey(for: type))
                                
                                // Save the new POST time
                                AppState.shared.lastPostTime = Date()
                                
                                // If type is sleep, then refresh daily-records data
                                if (type == HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!){
                                    DailyRecordViewModel.shared.fetchDailyRecords(forceFetch: true)
                                }
                            } catch {
                                Self.logger.error("Error archiving anchor: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    }
                }
                
                // MARK: if type is `heartbeat`
                if type == HKSeriesType.heartbeat(), let heartbeatSeriesSamples = filteredSamples as? [HKHeartbeatSeriesSample] {
                    if !heartbeatSeriesSamples.isEmpty {
                        self.getHeartbeatSubsamples(heartbeatSamples: heartbeatSeriesSamples) { formattedSubsamples in
                            let subsamplesUrl = Config.heartBeatSubsamplesEndpoint(pseudonym: pseudonym)
                            
                            DispatchQueue.main.async {
                                AppState.shared.queuedRequests += 1
                                AppState.shared.syncingTotalRequests += 1
                            }
                            
                            APIService.modifySamples(to: subsamplesUrl, with: formattedSubsamples, method: HTTPMethod.post, description: "heart-beat-subsamples"){ success in
                                DispatchQueue.main.async {
                                    AppState.shared.queuedRequests -= 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startQuery(for sampleType: HKSampleType, isLongRunning: Bool, completion: @escaping ([HKSample], [HKDeletedObject], HKQueryAnchor?) -> Void) {
        // --- Anchor ---
        var myAnchor: HKQueryAnchor?
        let anchorKey = "anchor-\(sampleTypeToBackendMapping[sampleType] ?? "")"
        
        if let anchorData = UserDefaults.standard.object(forKey: anchorKey) as? Data {
            do {
                myAnchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
            } catch {
                Self.logger.error("Error unarchiving anchor: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        // --- Predicate ---:
        // - no earlier than the start of the study period
        // - no user input
        var predicate: NSPredicate?
        if let startDate = ParticipantInfoModel.studyPeriod?.startDate,
           let endDate = ParticipantInfoModel.studyPeriod?.endDate {
            
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
            let metadataPredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
            
            // Combine predicates using AND
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, metadataPredicate])
        }
        
        // Documentation
        // https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery/1615071-init
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { query, samplesOrNil, deletedObjectsOrNil, queryAnchorOrNil, errorOrNil in
            if let error = errorOrNil {
                Self.logger.error("Error querying \(sampleType.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                completion([], [], nil) // return 2 empty arrays for samples and deletedObjects if error
                return
            }
            
            let samples = samplesOrNil ?? []
            let deletedObjects = deletedObjectsOrNil ?? []
            
            completion(samples, deletedObjects, queryAnchorOrNil)
        }
        
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: myAnchor,
            limit: HKObjectQueryNoLimit,
            resultsHandler: updateHandler
        )
        
        if (isLongRunning){
            query.updateHandler = updateHandler
        }
        
        hkHealthStore.execute(query)
    }
    
    private func getHeartbeatSubsamples(heartbeatSamples: [HKHeartbeatSeriesSample], completion: @escaping ([HeartbeatSubsample]) -> Void) {
        var heartbeatData = [HeartbeatSubsample]()
        let group = DispatchGroup()
        
        for seriesSample in heartbeatSamples {
            group.enter()  // Enter the group for each series
            
            let seriesQuery = HKHeartbeatSeriesQuery(heartbeatSeries: seriesSample) { query, timeSinceStart, precededByGap, done, error in
                if let error = error {
                    Self.logger.error("Error enumerating heartbeat series: \(error.localizedDescription, privacy: .public)")
                } else {
                    let heartbeatInfo = HeartbeatSubsample(
                        id: seriesSample.uuid.uuidString,
                        tsss: timeSinceStart,
                        pbg: precededByGap,
                        d: done
                    )
                    heartbeatData.append(heartbeatInfo)
                }
                
                // Leave the group when the query is fully done
                if done {
                    group.leave()
                }
            }
            
            hkHealthStore.execute(seriesQuery)
        }
        
        // Notify once all queries have completed
        group.notify(queue: .main) {
            completion(heartbeatData)
        }
    }
    
    // MARK: - Authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        hkHealthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                Self.logger.error("Error requesting HealthKit authorization: \(error.localizedDescription, privacy: .public)")
            }
            completion(success)
        }
    }
    
    
    // MARK: - Helper functions to format content for POST
    let isoFormatter = ISO8601DateFormatter()
    private func formatSampleToPost(_ sample: HKSample) -> HealthData {
        // Format the sample into a dictionary that the backend API expects
        let startDateString = isoFormatter.string(from: sample.startDate)
        let endDateString = isoFormatter.string(from: sample.endDate)
        
        var val: Double?
        var count: Int?
        var heartRateMotionContext: Int?
        var algorithmVersion: Int?
        var timeZone: String?
        var barometricPressure: Double?
        
        // Check if it's a quantity sample (e.g., heart rate, oxygen saturation)
        if let quantitySample = sample as? HKQuantitySample {
            let quantity = quantitySample.quantity  // Get the HKQuantity object
            let quantityType = quantitySample.quantityType  // Get the type of quantity (e.g., heart rate, oxygen saturation)
            
            var unit: HKUnit?
            count = quantitySample.count
            
            // Mapping HKQuantityType to corresponding HKUnit
            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
                val = quantity.doubleValue(for: .percent())
                if let bp = quantitySample.metadata?[HKMetadataKeyBarometricPressure] as? HKQuantity {
                    barometricPressure = bp.doubleValue(for: .pascalUnit(with: .kilo))
                }
                
            case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
                val = quantity.doubleValue(for: .secondUnit(with: .milli))
                
                // Retrieve the algorithmVersion if available
                if let version = quantitySample.metadata?[HKMetadataKeyAlgorithmVersion] as? Int {
                    algorithmVersion = version
                }
                
            case HKQuantityTypeIdentifier.restingHeartRate.rawValue, HKQuantityTypeIdentifier.heartRate.rawValue,
                HKQuantityTypeIdentifier.respiratoryRate.rawValue:
                unit = HKUnit.count().unitDivided(by: .minute())  // in count/min
                val = quantity.doubleValue(for: unit!)
                
                // Retrieve the heart rate motion context if available
                if let motionContext = quantitySample.metadata?[HKMetadataKeyHeartRateMotionContext] as? Int {
                    heartRateMotionContext = motionContext
                }
                
            default:
                break
            }
        } else if let categorySample = sample as? HKCategorySample {
            // Handle category sample types, e.g., SleepAnalysis, which doesn't involve a quantity
            val = Double(categorySample.value)
            
            // Retrieve the timeZone if available
            if let tz = categorySample.metadata?[HKMetadataKeyTimeZone] as? String {
                timeZone = tz
            }
        } else if let heartbeatSample = sample as? HKHeartbeatSeriesSample {
            // Handle HKSeriesType.heartbeat
            count = heartbeatSample.count // Store the count of heartbeat segments
            
            // Retrieve the algorithmVersion if available
            if let version = heartbeatSample.metadata?[HKMetadataKeyAlgorithmVersion] as? Int {
                algorithmVersion = version
            }
        }
        
        // Prepare the data, ensuring we send null for missing fields
        return HealthData(
            id: sample.uuid.uuidString,
            stid: sampleTypeToBackendMapping[sample.sampleType] ?? nil,
            sd: startDateString,
            ed: endDateString,
            hud: sample.hasUndeterminedDuration,
            v: val,
            c: count,
            hrmc: heartRateMotionContext,
            av: algorithmVersion,
            tz: timeZone,
            bp: barometricPressure
        )
    }
}
