import Foundation
import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    weak var countdownManager: CountdownManager?
    
    private override init() {
        super.init()
    }
    
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories
        let startNextAction = UNNotificationAction(
            identifier: "START_NEXT",
            title: "Start Next Block",
            options: [.foreground]
        )
        
        let skipAction = UNNotificationAction(
            identifier: "SKIP",
            title: "Skip",
            options: []
        )
        
        let countdownCategory = UNNotificationCategory(
            identifier: "COUNTDOWN_COMPLETE",
            actions: [startNextAction, skipAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([countdownCategory])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        let notificationId = response.notification.request.identifier
        
        Task { @MainActor in
            switch actionId {
            case "START_NEXT", UNNotificationDefaultActionIdentifier:
                // User tapped "Start Next Block" or the notification itself
                countdownManager?.startNextCountdownFromNotification(notificationId: notificationId)
                
            case "SKIP":
                // User chose to skip
                break
                
            default:
                break
            }
        }
        
        completionHandler()
    }
}
