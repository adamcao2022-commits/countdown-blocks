import Foundation
import SwiftData

@Model
final class DailyStats {
    var id: UUID
    var date: Date
    
    // Hours tracked (stored in minutes for precision)
    var sleepMinutes: Int
    var workMinutes: Int
    var morningFreeTimeMinutes: Int
    var eveningFreeTimeMinutes: Int
    
    // Completion tracking
    var countdownsCompleted: Int
    var countdownsSkipped: Int
    
    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.sleepMinutes = 0
        self.workMinutes = 0
        self.morningFreeTimeMinutes = 0
        self.eveningFreeTimeMinutes = 0
        self.countdownsCompleted = 0
        self.countdownsSkipped = 0
    }
    
    // Computed hours
    var hoursSlept: Double { Double(sleepMinutes) / 60.0 }
    var hoursWorked: Double { Double(workMinutes) / 60.0 }
    var morningFreeTimeHours: Double { Double(morningFreeTimeMinutes) / 60.0 }
    var eveningFreeTimeHours: Double { Double(eveningFreeTimeMinutes) / 60.0 }
    
    // Formatted strings
    var formattedSleep: String { formatHours(hoursSlept) }
    var formattedWork: String { formatHours(hoursWorked) }
    var formattedMorningFreeTime: String { formatHours(morningFreeTimeHours) }
    var formattedEveningFreeTime: String { formatHours(eveningFreeTimeHours) }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}

// MARK: - Stats Aggregation
struct StatsAggregate {
    let period: StatsPeriod
    let startDate: Date
    let endDate: Date
    
    var totalSleepHours: Double
    var totalWorkHours: Double
    var totalMorningFreeTimeHours: Double
    var totalEveningFreeTimeHours: Double
    var daysTracked: Int
    
    var averageSleepHours: Double {
        guard daysTracked > 0 else { return 0 }
        return totalSleepHours / Double(daysTracked)
    }
    
    var averageWorkHours: Double {
        guard daysTracked > 0 else { return 0 }
        return totalWorkHours / Double(daysTracked)
    }
    
    var averageMorningFreeTimeHours: Double {
        guard daysTracked > 0 else { return 0 }
        return totalMorningFreeTimeHours / Double(daysTracked)
    }
    
    var averageEveningFreeTimeHours: Double {
        guard daysTracked > 0 else { return 0 }
        return totalEveningFreeTimeHours / Double(daysTracked)
    }
    
    init(period: StatsPeriod, stats: [DailyStats]) {
        self.period = period
        self.daysTracked = stats.count
        
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .day:
            self.startDate = calendar.startOfDay(for: now)
            self.endDate = now
        case .week:
            self.startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            self.endDate = now
        case .month:
            self.startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            self.endDate = now
        case .year:
            self.startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            self.endDate = now
        }
        
        self.totalSleepHours = stats.reduce(0) { $0 + $1.hoursSlept }
        self.totalWorkHours = stats.reduce(0) { $0 + $1.hoursWorked }
        self.totalMorningFreeTimeHours = stats.reduce(0) { $0 + $1.morningFreeTimeHours }
        self.totalEveningFreeTimeHours = stats.reduce(0) { $0 + $1.eveningFreeTimeHours }
    }
}

enum StatsPeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
}
