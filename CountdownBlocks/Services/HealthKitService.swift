import Foundation
import HealthKit

/// Service for HealthKit integration (sleep schedule)
@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var nextWakeTime: Date?
    @Published var sleepSchedule: SleepSchedule?
    
    private init() {}
    
    // MARK: - Authorization
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            print("HealthKit not available")
            return false
        }
        
        // Types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await MainActor.run {
                isAuthorized = true
            }
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }
    
    // MARK: - Sleep Schedule
    
    /// Fetch the user's sleep schedule from HealthKit
    func fetchSleepSchedule() async {
        guard isAuthorized else { return }
        
        // Query for recent sleep analysis
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume()
                    return
                }
                
                // Analyze sleep patterns
                let schedule = self?.analyzeSleepPatterns(from: samples)
                
                Task { @MainActor in
                    self?.sleepSchedule = schedule
                    self?.nextWakeTime = schedule?.nextWakeTime()
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Analyze sleep samples to determine typical wake time
    private func analyzeSleepPatterns(from samples: [HKCategorySample]) -> SleepSchedule? {
        // Filter for "in bed" or "asleep" samples
        let sleepSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .inBed || value == .asleepCore || value == .asleepDeep || value == .asleepREM
        }
        
        guard !sleepSamples.isEmpty else { return nil }
        
        // Group samples by night
        var wakeTimeMinutes: [Int] = []
        var bedtimeMinutes: [Int] = []
        
        let calendar = Calendar.current
        
        for sample in sleepSamples {
            // Wake time is the end of the sleep sample
            let wakeComponents = calendar.dateComponents([.hour, .minute], from: sample.endDate)
            if let hour = wakeComponents.hour, let minute = wakeComponents.minute {
                // Only consider morning wake times (4 AM - 12 PM)
                if hour >= 4 && hour <= 12 {
                    wakeTimeMinutes.append(hour * 60 + minute)
                }
            }
            
            // Bedtime is the start of the sleep sample
            let bedComponents = calendar.dateComponents([.hour, .minute], from: sample.startDate)
            if let hour = bedComponents.hour, let minute = bedComponents.minute {
                // Only consider evening bedtimes (8 PM - 3 AM)
                var adjustedHour = hour
                if hour < 4 {
                    adjustedHour += 24 // Treat early morning as previous day
                }
                if adjustedHour >= 20 && adjustedHour <= 27 {
                    bedtimeMinutes.append(adjustedHour * 60 + minute)
                }
            }
        }
        
        guard !wakeTimeMinutes.isEmpty else { return nil }
        
        // Calculate average wake time
        let avgWakeMinutes = wakeTimeMinutes.reduce(0, +) / wakeTimeMinutes.count
        let avgWakeHour = avgWakeMinutes / 60
        let avgWakeMinute = avgWakeMinutes % 60
        
        // Calculate average bedtime (if available)
        var avgBedHour: Int?
        var avgBedMinute: Int?
        if !bedtimeMinutes.isEmpty {
            let avgBedMinutes = bedtimeMinutes.reduce(0, +) / bedtimeMinutes.count
            avgBedHour = (avgBedMinutes / 60) % 24
            avgBedMinute = avgBedMinutes % 60
        }
        
        return SleepSchedule(
            averageWakeHour: avgWakeHour,
            averageWakeMinute: avgWakeMinute,
            averageBedHour: avgBedHour,
            averageBedMinute: avgBedMinute,
            sampleCount: wakeTimeMinutes.count
        )
    }
}

// MARK: - Sleep Schedule Model

struct SleepSchedule {
    let averageWakeHour: Int
    let averageWakeMinute: Int
    let averageBedHour: Int?
    let averageBedMinute: Int?
    let sampleCount: Int
    
    /// Get the next wake time based on the schedule
    func nextWakeTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = averageWakeHour
        components.minute = averageWakeMinute
        components.second = 0
        
        guard var wakeTime = calendar.date(from: components) else {
            return now
        }
        
        // If wake time has passed today, use tomorrow's wake time
        if wakeTime <= now {
            wakeTime = calendar.date(byAdding: .day, value: 1, to: wakeTime) ?? wakeTime
        }
        
        return wakeTime
    }
    
    /// Get the next bedtime based on the schedule
    func nextBedtime() -> Date? {
        guard let bedHour = averageBedHour, let bedMinute = averageBedMinute else {
            return nil
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = bedHour
        components.minute = bedMinute
        components.second = 0
        
        guard var bedtime = calendar.date(from: components) else {
            return nil
        }
        
        // If bedtime has passed today, use tomorrow's bedtime
        if bedtime <= now {
            bedtime = calendar.date(byAdding: .day, value: 1, to: bedtime) ?? bedtime
        }
        
        return bedtime
    }
    
    /// Formatted average wake time string
    var formattedWakeTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = averageWakeHour
        components.minute = averageWakeMinute
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(averageWakeHour):\(String(format: "%02d", averageWakeMinute))"
    }
    
    /// Formatted average bedtime string
    var formattedBedtime: String? {
        guard let bedHour = averageBedHour, let bedMinute = averageBedMinute else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = bedHour
        components.minute = bedMinute
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(bedHour):\(String(format: "%02d", bedMinute))"
    }
}
