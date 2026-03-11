import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    
    // Alarm reference (manual entry since iOS doesn't expose Clock alarms)
    var wakeUpTime: Date
    var selectedAlarmTime: Date?
    
    // Work schedule
    var workStartTime: Date
    var workEndTime: Date
    var bedtimeTarget: Date
    
    // Per-day overrides stored as JSON
    var dayOverridesData: Data?
    
    // Reminders list mappings
    var morningReminderListId: String?
    var workdayReminderListId: String?
    var eveningReminderListId: String?
    
    // App preferences
    var isDarkMode: Bool
    var notificationsEnabled: Bool
    var hapticFeedbackEnabled: Bool
    
    // Tracking
    var firstLaunchDate: Date
    var totalActiveDays: Int
    var lastActiveDate: Date?
    
    init() {
        self.id = UUID()
        
        // Default times
        let calendar = Calendar.current
        let today = Date()
        
        self.wakeUpTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today) ?? today
        self.workStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        self.workEndTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) ?? today
        self.bedtimeTarget = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today) ?? today
        
        self.isDarkMode = true
        self.notificationsEnabled = true
        self.hapticFeedbackEnabled = true
        
        self.firstLaunchDate = today
        self.totalActiveDays = 1
    }
    
    // Per-day schedule overrides
    var dayOverrides: [DayOfWeek: DayScheduleOverride] {
        get {
            guard let data = dayOverridesData else { return [:] }
            return (try? JSONDecoder().decode([DayOfWeek: DayScheduleOverride].self, from: data)) ?? [:]
        }
        set {
            dayOverridesData = try? JSONEncoder().encode(newValue)
        }
    }
    
    func schedule(for day: DayOfWeek) -> DaySchedule {
        if let override = dayOverrides[day] {
            return DaySchedule(
                wakeUpTime: override.wakeUpTime ?? wakeUpTime,
                workStartTime: override.workStartTime ?? workStartTime,
                workEndTime: override.workEndTime ?? workEndTime,
                bedtimeTarget: override.bedtimeTarget ?? bedtimeTarget
            )
        }
        return DaySchedule(
            wakeUpTime: wakeUpTime,
            workStartTime: workStartTime,
            workEndTime: workEndTime,
            bedtimeTarget: bedtimeTarget
        )
    }
    
    // Calculate hours of sleep based on bedtime and wake time
    func hoursOfSleep(for day: DayOfWeek) -> Double {
        let schedule = self.schedule(for: day)
        let calendar = Calendar.current
        
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: schedule.bedtimeTarget)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: schedule.wakeUpTime)
        
        var bedtimeMinutes = (bedtimeComponents.hour ?? 22) * 60 + (bedtimeComponents.minute ?? 0)
        var wakeMinutes = (wakeComponents.hour ?? 7) * 60 + (wakeComponents.minute ?? 0)
        
        // If wake time is earlier than bedtime, add 24 hours worth of minutes
        if wakeMinutes <= bedtimeMinutes {
            wakeMinutes += 24 * 60
        }
        
        let sleepMinutes = wakeMinutes - bedtimeMinutes
        return Double(sleepMinutes) / 60.0
    }
}

// MARK: - Day Schedule
struct DaySchedule {
    let wakeUpTime: Date
    let workStartTime: Date
    let workEndTime: Date
    let bedtimeTarget: Date
}

// MARK: - Day Schedule Override
struct DayScheduleOverride: Codable {
    var wakeUpTime: Date?
    var workStartTime: Date?
    var workEndTime: Date?
    var bedtimeTarget: Date?
}
