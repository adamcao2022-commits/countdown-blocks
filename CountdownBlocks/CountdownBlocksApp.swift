import SwiftUI
import SwiftData
import UserNotifications

@main
struct CountdownBlocksApp: App {
    @StateObject private var countdownManager = CountdownManager()
    
    let modelContainer: ModelContainer
    
    init() {
        // Configure model container
        let schema = Schema([
            Countdown.self,
            UserSettings.self,
            DailyStats.self,
            CountdownHistory.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Configure notifications
        NotificationService.shared.configure()
        requestNotificationPermissions()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(countdownManager)
                .onAppear {
                    NotificationService.shared.countdownManager = countdownManager
                }
        }
        .modelContainer(modelContainer)
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            }
        }
    }
}
