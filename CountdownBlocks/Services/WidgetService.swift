import Foundation
import WidgetKit

/// Service for sharing data between the main app and widgets
class WidgetService {
    static let shared = WidgetService()
    
    // App Group identifier - must be set up in Xcode
    private let appGroupId = "group.com.countdownblocks.shared"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let activeCountdownTitle = "activeCountdownTitle"
        static let activeCountdownType = "activeCountdownType"
        static let activeCountdownTargetDate = "activeCountdownTargetDate"
        static let activeCountdownIsPaused = "activeCountdownIsPaused"
        static let lastUpdate = "lastUpdate"
    }
    
    // MARK: - Update Widget Data
    
    func updateActiveCountdown(
        title: String?,
        type: String?,
        targetDate: Date?,
        isPaused: Bool
    ) {
        guard let defaults = sharedDefaults else {
            print("Widget Service: Failed to access shared defaults")
            return
        }
        
        if let title = title {
            defaults.set(title, forKey: Keys.activeCountdownTitle)
        } else {
            defaults.removeObject(forKey: Keys.activeCountdownTitle)
        }
        
        if let type = type {
            defaults.set(type, forKey: Keys.activeCountdownType)
        } else {
            defaults.removeObject(forKey: Keys.activeCountdownType)
        }
        
        if let targetDate = targetDate {
            defaults.set(targetDate, forKey: Keys.activeCountdownTargetDate)
        } else {
            defaults.removeObject(forKey: Keys.activeCountdownTargetDate)
        }
        
        defaults.set(isPaused, forKey: Keys.activeCountdownIsPaused)
        defaults.set(Date(), forKey: Keys.lastUpdate)
        
        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func clearActiveCountdown() {
        updateActiveCountdown(title: nil, type: nil, targetDate: nil, isPaused: false)
    }
    
    // MARK: - Read Widget Data (for widget extension)
    
    func getActiveCountdownData() -> (title: String, type: String, targetDate: Date?, isPaused: Bool)? {
        guard let defaults = sharedDefaults,
              let title = defaults.string(forKey: Keys.activeCountdownTitle),
              let type = defaults.string(forKey: Keys.activeCountdownType) else {
            return nil
        }
        
        let targetDate = defaults.object(forKey: Keys.activeCountdownTargetDate) as? Date
        let isPaused = defaults.bool(forKey: Keys.activeCountdownIsPaused)
        
        return (title, type, targetDate, isPaused)
    }
    
    // MARK: - Calculate Time Remaining
    
    static func formatTimeRemaining(from targetDate: Date?) -> String {
        guard let target = targetDate else { return "--:--" }
        
        let remaining = target.timeIntervalSinceNow
        guard remaining > 0 else { return "0m" }
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
