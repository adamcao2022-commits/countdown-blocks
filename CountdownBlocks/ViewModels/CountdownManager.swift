import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import Combine
import ActivityKit

@MainActor
class CountdownManager: ObservableObject {
    @Published var activeCountdown: Countdown?
    @Published var countdowns: [Countdown] = []
    @Published var todayStats: DailyStats?
    @Published var settings: UserSettings?
    @Published var isLoading = true
    @Published var healthKitWakeTime: Date?
    
    private var modelContext: ModelContext?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let liveActivityService = LiveActivityService.shared
    private let healthKitService = HealthKitService.shared
    
    init() {
        startTimer()
    }
    
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
        
        // Load HealthKit sleep schedule if authorized
        Task {
            await loadHealthKitSleepSchedule()
        }
    }
    
    // MARK: - HealthKit Integration
    
    func requestHealthKitAccess() async -> Bool {
        let authorized = await healthKitService.requestAuthorization()
        if authorized {
            await loadHealthKitSleepSchedule()
        }
        return authorized
    }
    
    private func loadHealthKitSleepSchedule() async {
        guard healthKitService.isAuthorized else { return }
        
        await healthKitService.fetchSleepSchedule()
        
        if let wakeTime = healthKitService.nextWakeTime {
            healthKitWakeTime = wakeTime
            
            // Optionally auto-update settings wake time
            if let settings = settings {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: wakeTime)
                if let hour = components.hour, let minute = components.minute {
                    // Create a date with just the time component
                    settings.wakeUpTime = calendar.date(
                        bySettingHour: hour,
                        minute: minute,
                        second: 0,
                        of: Date()
                    ) ?? settings.wakeUpTime
                }
            }
        }
    }
    
    var sleepSchedule: SleepSchedule? {
        healthKitService.sleepSchedule
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        guard let context = modelContext else { return }
        
        // Load countdowns
        let countdownDescriptor = FetchDescriptor<Countdown>(
            sortBy: [SortDescriptor(\.order)]
        )
        countdowns = (try? context.fetch(countdownDescriptor)) ?? []
        
        // Load or create settings
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        if let existingSettings = try? context.fetch(settingsDescriptor).first {
            settings = existingSettings
        } else {
            let newSettings = UserSettings()
            context.insert(newSettings)
            settings = newSettings
            try? context.save()
        }
        
        // Load or create today's stats
        loadTodayStats()
        
        // Set active countdown
        activeCountdown = countdowns.first { $0.isActive && !$0.isPaused }
        
        // Create default countdowns if none exist
        if countdowns.isEmpty {
            createDefaultCountdowns()
        }
        
        isLoading = false
    }
    
    private func loadTodayStats() {
        guard let context = modelContext else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.date == today }
        )
        
        if let existingStats = try? context.fetch(descriptor).first {
            todayStats = existingStats
        } else {
            let newStats = DailyStats(date: today)
            context.insert(newStats)
            todayStats = newStats
            try? context.save()
            
            // Increment active days
            if let settings = settings {
                settings.totalActiveDays += 1
                settings.lastActiveDate = Date()
            }
        }
    }
    
    // MARK: - Default Countdowns
    
    private func createDefaultCountdowns() {
        guard let context = modelContext, let settings = settings else { return }
        
        let defaults: [(String, CountdownType, Int)] = [
            ("Wake Up", .wakeUp, 0),
            ("Morning Free Time", .morningFreeTime, 1),
            ("Work", .work, 2),
            ("Evening Free Time", .eveningFreeTime, 3),
            ("Bedtime", .bedtime, 4)
        ]
        
        for (title, type, order) in defaults {
            let countdown = Countdown(title: title, type: type, order: order)
            
            // Set default configurations for all days
            var configs: [DayOfWeek: DayConfiguration] = [:]
            let schedule = settings.schedule(for: .monday) // Use default schedule
            
            for day in DayOfWeek.allCases {
                let targetTime: Date
                switch type {
                case .wakeUp:
                    targetTime = schedule.wakeUpTime
                case .morningFreeTime:
                    targetTime = schedule.workStartTime
                case .work:
                    targetTime = schedule.workEndTime
                case .eveningFreeTime:
                    targetTime = schedule.bedtimeTarget
                case .bedtime:
                    targetTime = schedule.wakeUpTime // Next day's wake time
                case .custom:
                    continue
                }
                configs[day] = DayConfiguration(targetTime: targetTime)
            }
            
            countdown.dayConfigurations = configs
            context.insert(countdown)
            countdowns.append(countdown)
        }
        
        try? context.save()
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkCountdowns()
            }
        }
    }
    
    private func checkCountdowns() {
        guard let active = activeCountdown else { return }
        
        if let remaining = active.timeRemaining(), remaining <= 0 {
            countdownComplete(active)
        }
        
        objectWillChange.send()
    }
    
    // MARK: - Countdown Actions
    
    func startCountdown(_ countdown: Countdown) {
        // Deactivate current active
        if let current = activeCountdown {
            current.isActive = false
        }
        
        countdown.isActive = true
        countdown.isPaused = false
        activeCountdown = countdown
        
        scheduleNotification(for: countdown)
        
        // Start Live Activity
        startLiveActivity(for: countdown)
        
        save()
    }
    
    private func startLiveActivity(for countdown: Countdown) {
        guard let targetDate = getTargetDate(for: countdown), targetDate > Date() else {
            return
        }
        
        // Calculate sleep hours for bedtime countdown
        var sleepHours: Double?
        if countdown.type == .bedtime, let settings = settings {
            sleepHours = settings.hoursOfSleep(for: DayOfWeek.today)
        }
        
        liveActivityService.startActivity(
            title: countdown.title,
            type: countdown.type.rawValue,
            targetDate: targetDate,
            sleepHours: sleepHours
        )
    }
    
    private func getTargetDate(for countdown: Countdown) -> Date? {
        if let customTarget = countdown.targetDate {
            return customTarget
        }
        
        guard let dayTarget = countdown.targetTime(for: DayOfWeek.today) else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: dayTarget)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: Date()
        )
    }
    
    func pauseCountdown(_ countdown: Countdown) {
        countdown.isPaused = true
        cancelNotification(for: countdown)
        
        // Update Live Activity
        Task {
            await liveActivityService.updateActivity(isPaused: true)
        }
        
        save()
    }
    
    func resumeCountdown(_ countdown: Countdown) {
        countdown.isPaused = false
        scheduleNotification(for: countdown)
        
        // Update Live Activity
        Task {
            await liveActivityService.updateActivity(isPaused: false)
        }
        
        save()
    }
    
    func skipCountdown(_ countdown: Countdown) {
        countdown.isActive = false
        countdown.isPaused = false
        cancelNotification(for: countdown)
        
        // End Live Activity
        Task {
            await liveActivityService.endCurrentActivity()
        }
        
        // Update stats
        todayStats?.countdownsSkipped += 1
        
        // Start next in sequence
        startNextCountdown(after: countdown)
        save()
    }
    
    private func countdownComplete(_ countdown: Countdown) {
        countdown.isActive = false
        countdown.completedAt = Date()
        
        // Update stats based on type
        updateStats(for: countdown)
        
        // End Live Activity (keep visible for 5 seconds)
        Task {
            await liveActivityService.endActivity(after: 5)
        }
        
        // Send completion notification
        sendCompletionNotification(for: countdown)
        
        save()
    }
    
    func startNextCountdown(after countdown: Countdown) {
        let nextOrder = countdown.order + 1
        if let next = countdowns.first(where: { $0.order == nextOrder }) {
            startCountdown(next)
        } else {
            // Loop back to first countdown (next day)
            if let first = countdowns.first {
                startCountdown(first)
            }
        }
    }
    
    // MARK: - Custom Countdowns
    
    func createCustomCountdown(title: String, duration: TimeInterval) {
        guard let context = modelContext else { return }
        
        let countdown = Countdown(title: title, type: .custom, isRecurring: false, order: countdowns.count)
        countdown.targetDate = Date().addingTimeInterval(duration)
        countdown.durationMinutes = Int(duration / 60)
        
        context.insert(countdown)
        countdowns.append(countdown)
        
        // Add to history
        let history = CountdownHistory(title: title, durationMinutes: countdown.durationMinutes ?? 0)
        context.insert(history)
        
        save()
    }
    
    // MARK: - Edit Countdown
    
    enum EditScope {
        case todayOnly
        case thisDay
        case allDays
    }
    
    func editCountdown(_ countdown: Countdown, newTime: Date, scope: EditScope) {
        switch scope {
        case .todayOnly:
            countdown.targetDate = newTime
        case .thisDay:
            let today = DayOfWeek.today
            var configs = countdown.dayConfigurations
            configs[today] = DayConfiguration(targetTime: newTime)
            countdown.dayConfigurations = configs
        case .allDays:
            var configs = countdown.dayConfigurations
            for day in DayOfWeek.allCases {
                configs[day] = DayConfiguration(targetTime: newTime)
            }
            countdown.dayConfigurations = configs
        }
        
        if countdown.isActive {
            scheduleNotification(for: countdown)
        }
        
        save()
    }
    
    // MARK: - Stats
    
    private func updateStats(for countdown: Countdown) {
        guard let stats = todayStats else { return }
        
        stats.countdownsCompleted += 1
        
        switch countdown.type {
        case .wakeUp:
            break // Sleep was tracked at bedtime
        case .morningFreeTime:
            if let remaining = countdown.timeRemaining() {
                stats.morningFreeTimeMinutes += max(0, Int(-remaining / 60))
            }
        case .work:
            if let remaining = countdown.timeRemaining() {
                stats.workMinutes += max(0, Int(-remaining / 60))
            }
        case .eveningFreeTime:
            if let remaining = countdown.timeRemaining() {
                stats.eveningFreeTimeMinutes += max(0, Int(-remaining / 60))
            }
        case .bedtime:
            if let settings = settings {
                let sleepHours = settings.hoursOfSleep(for: DayOfWeek.today)
                stats.sleepMinutes = Int(sleepHours * 60)
            }
        case .custom:
            break
        }
    }
    
    // MARK: - Notifications
    
    private func scheduleNotification(for countdown: Countdown) {
        guard let remaining = countdown.timeRemaining(), remaining > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = countdown.title
        content.body = "Time's up!"
        content.sound = .default
        content.categoryIdentifier = "COUNTDOWN_COMPLETE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(
            identifier: countdown.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelNotification(for countdown: Countdown) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [countdown.id.uuidString]
        )
    }
    
    private func sendCompletionNotification(for countdown: Countdown) {
        let content = UNMutableNotificationContent()
        content.title = countdown.title
        content.body = "Countdown complete! Ready for the next block?"
        content.sound = .default
        content.categoryIdentifier = "COUNTDOWN_COMPLETE"
        
        let request = UNNotificationRequest(
            identifier: "\(countdown.id.uuidString)-complete",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Notification Handling
    
    func startNextCountdownFromNotification(notificationId: String) {
        // Find the completed countdown by its ID
        if let completed = countdowns.first(where: { $0.id.uuidString == notificationId.replacingOccurrences(of: "-complete", with: "") }) {
            startNextCountdown(after: completed)
        } else if let active = activeCountdown {
            startNextCountdown(after: active)
        }
    }
    
    // MARK: - Widget Sync
    
    private func syncWidget() {
        if let active = activeCountdown {
            let targetDate: Date?
            if let customTarget = active.targetDate {
                targetDate = customTarget
            } else if let dayTarget = active.targetTime(for: DayOfWeek.today) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: dayTarget)
                targetDate = calendar.date(
                    bySettingHour: components.hour ?? 0,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: Date()
                )
            } else {
                targetDate = nil
            }
            
            WidgetService.shared.updateActiveCountdown(
                title: active.title,
                type: active.type.rawValue,
                targetDate: targetDate,
                isPaused: active.isPaused
            )
        } else {
            WidgetService.shared.clearActiveCountdown()
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        try? modelContext?.save()
        syncWidget()
    }
}
