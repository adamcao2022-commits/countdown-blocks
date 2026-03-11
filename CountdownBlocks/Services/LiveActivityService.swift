import Foundation
import ActivityKit
import SwiftUI

/// Service to manage Live Activities for countdown timers
@MainActor
class LiveActivityService: ObservableObject {
    static let shared = LiveActivityService()
    
    @Published var currentActivity: Activity<CountdownActivityAttributes>?
    
    private init() {}
    
    // MARK: - Activity Management
    
    /// Start a Live Activity for a countdown
    func startActivity(
        title: String,
        type: String,
        targetDate: Date,
        sleepHours: Double? = nil
    ) {
        // End any existing activity first
        Task {
            await endCurrentActivity()
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        let attributes = CountdownActivityAttributes(
            title: title,
            type: type,
            targetDate: targetDate,
            iconName: CountdownActivityAttributes.iconName(for: type)
        )
        
        let initialState = CountdownActivityAttributes.ContentState(
            isPaused: false,
            sleepHours: sleepHours
        )
        
        let content = ActivityContent(
            state: initialState,
            staleDate: targetDate.addingTimeInterval(60) // Stale 1 minute after target
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    /// Update the current Live Activity (e.g., pause state)
    func updateActivity(isPaused: Bool, sleepHours: Double? = nil) async {
        guard let activity = currentActivity else { return }
        
        let updatedState = CountdownActivityAttributes.ContentState(
            isPaused: isPaused,
            sleepHours: sleepHours
        )
        
        let content = ActivityContent(
            state: updatedState,
            staleDate: nil
        )
        
        await activity.update(content)
    }
    
    /// End the current Live Activity
    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = CountdownActivityAttributes.ContentState(
            isPaused: false,
            sleepHours: nil
        )
        
        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )
        
        await activity.end(content, dismissalPolicy: .immediate)
        currentActivity = nil
    }
    
    /// End activity with a specific dismissal policy
    func endActivity(after seconds: TimeInterval) async {
        guard let activity = currentActivity else { return }
        
        let finalState = CountdownActivityAttributes.ContentState(
            isPaused: false,
            sleepHours: nil
        )
        
        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )
        
        await activity.end(
            content,
            dismissalPolicy: .after(Date().addingTimeInterval(seconds))
        )
        currentActivity = nil
    }
    
    // MARK: - Activity Status
    
    var isActivityActive: Bool {
        currentActivity?.activityState == .active
    }
    
    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
