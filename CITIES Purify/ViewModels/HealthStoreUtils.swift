import HealthKit

let sampleTypeToBackendMapping: [HKSampleType: String] = [
    HKSeriesType.heartbeat(): "heartbeat-series",
    HKObjectType.quantityType(forIdentifier: .heartRate)!: "heart-rate",
    HKObjectType.quantityType(forIdentifier: .restingHeartRate)!: "resting-heart-rate",
    HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!: "hrv",
    HKObjectType.quantityType(forIdentifier: .respiratoryRate)!: "respiratory-rate",
    HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!: "oxygen-saturation",
    HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!: "sleep"
]

// The data types we want to read
let typesToRead: Set<HKSampleType> = [
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
    HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
    HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
    HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
    HKSeriesType.heartbeat()
]

func generateAnchorKey(for type: HKSampleType) -> String {
    return "anchor-\(sampleTypeToBackendMapping[type] ?? "unknown")"
}
