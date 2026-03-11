import Foundation
import SwiftData

// MARK: - Countdown Types
enum CountdownType: String, Codable, CaseIterable {
    case wakeUp = "Wake Up"
    case morningFreeTime = "Morning Free Time"
    case work = "Work"
    case eveningFreeTime = "Evening Free Time"
    case bedtime = "Bedtime"
    case custom = "Custom"
}

// MARK: - Day of Week
enum DayOfWeek: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var id: Int { rawValue }
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    static var today: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return DayOfWeek(rawValue: weekday) ?? .sunday
    }
}

// MARK: - Time Block (for Reminders integration)
enum TimeBlock: String, Codable, CaseIterable {
    case morning = "Morning"
    case workday = "Workday"
    case evening = "Evening"
}

// MARK: - Countdown Model
@Model
final class Countdown {
    var id: UUID
    var title: String
    var type: CountdownType
    var isRecurring: Bool
    var isActive: Bool
    var isPaused: Bool
    var order: Int
    
    // Time configuration per day (stored as JSON)
    var dayConfigurationsData: Data?
    
    // For custom (one-off) countdowns
    var targetDate: Date?
    var durationMinutes: Int?
    
    // For reminders integration
    var linkedReminderListId: String?
    var timeBlock: TimeBlock?
    
    var createdAt: Date
    var completedAt: Date?
    
    init(
        title: String,
        type: CountdownType,
        isRecurring: Bool = true,
        order: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.isRecurring = isRecurring
        self.isActive = false
        self.isPaused = false
        self.order = order
        self.createdAt = Date()
    }
    
    // Computed property for day configurations
    var dayConfigurations: [DayOfWeek: DayConfiguration] {
        get {
            guard let data = dayConfigurationsData else { return [:] }
            return (try? JSONDecoder().decode([DayOfWeek: DayConfiguration].self, from: data)) ?? [:]
        }
        set {
            dayConfigurationsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    func targetTime(for day: DayOfWeek) -> Date? {
        return dayConfigurations[day]?.targetTime
    }
    
    func timeRemaining(from now: Date = Date()) -> TimeInterval? {
        if let targetDate = targetDate {
            return targetDate.timeIntervalSince(now)
        }
        
        let today = DayOfWeek.today
        guard let targetTime = targetTime(for: today) else { return nil }
        
        let calendar = Calendar.current
        let targetComponents = calendar.dateComponents([.hour, .minute], from: targetTime)
        
        guard let todayTarget = calendar.date(
            bySettingHour: targetComponents.hour ?? 0,
            minute: targetComponents.minute ?? 0,
            second: 0,
            of: now
        ) else { return nil }
        
        return todayTarget.timeIntervalSince(now)
    }
    
    var formattedTimeRemaining: String {
        guard let remaining = timeRemaining(), remaining > 0 else {
            return "0h 0m"
        }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Day Configuration
struct DayConfiguration: Codable {
    var targetTime: Date
    var isEnabled: Bool
    
    init(targetTime: Date, isEnabled: Bool = true) {
        self.targetTime = targetTime
        self.isEnabled = isEnabled
    }
}

// MARK: - Countdown History (for custom countdowns)
@Model
final class CountdownHistory {
    var id: UUID
    var title: String
    var durationMinutes: Int
    var startedAt: Date
    var completedAt: Date?
    
    init(title: String, durationMinutes: Int, startedAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.durationMinutes = durationMinutes
        self.startedAt = startedAt
    }
}
