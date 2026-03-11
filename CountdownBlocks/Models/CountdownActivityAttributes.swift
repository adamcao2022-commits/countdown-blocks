import Foundation
import ActivityKit

/// Attributes for the Countdown Blocks Live Activity
struct CountdownActivityAttributes: ActivityAttributes {
    /// Static attributes that don't change during the activity
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var sleepHours: Double?  // Only for bedtime countdown
    }
    
    // Fixed attributes set when activity starts
    var title: String
    var type: String
    var targetDate: Date
    var iconName: String
}

// MARK: - Activity Helpers

extension CountdownActivityAttributes {
    static func iconName(for type: String) -> String {
        switch type {
        case "Wake Up": return "sunrise.fill"
        case "Morning Free Time": return "cup.and.saucer.fill"
        case "Work": return "briefcase.fill"
        case "Evening Free Time": return "house.fill"
        case "Bedtime": return "moon.fill"
        default: return "timer"
        }
    }
    
    static func color(for type: String) -> String {
        switch type {
        case "Wake Up": return "orange"
        case "Morning Free Time": return "yellow"
        case "Work": return "blue"
        case "Evening Free Time": return "purple"
        case "Bedtime": return "indigo"
        default: return "gray"
        }
    }
}
