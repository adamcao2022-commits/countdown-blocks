import Foundation
import EventKit

@MainActor
class RemindersService: ObservableObject {
    private let eventStore = EKEventStore()
    
    @Published var isAuthorized = false
    @Published var reminderLists: [EKCalendar] = []
    @Published var currentReminders: [EKReminder] = []
    
    init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        isAuthorized = status == .fullAccess || status == .authorized
        
        if isAuthorized {
            loadReminderLists()
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                isAuthorized = granted
                if granted {
                    loadReminderLists()
                }
            }
            return granted
        } catch {
            print("Reminders access error: \(error)")
            return false
        }
    }
    
    // MARK: - Reminder Lists
    
    func loadReminderLists() {
        reminderLists = eventStore.calendars(for: .reminder)
    }
    
    func getReminderList(by identifier: String) -> EKCalendar? {
        return reminderLists.first { $0.calendarIdentifier == identifier }
    }
    
    // MARK: - Reminders
    
    func fetchReminders(from listId: String) async -> [EKReminder] {
        guard let calendar = getReminderList(by: listId) else { return [] }
        
        let predicate = eventStore.predicateForReminders(in: [calendar])
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let incomplete = (reminders ?? []).filter { !$0.isCompleted }
                continuation.resume(returning: incomplete)
            }
        }
    }
    
    func fetchRemindersForTimeBlock(
        _ block: TimeBlock,
        morningListId: String?,
        workdayListId: String?,
        eveningListId: String?
    ) async -> [EKReminder] {
        let listId: String?
        
        switch block {
        case .morning:
            listId = morningListId
        case .workday:
            listId = workdayListId
        case .evening:
            listId = eveningListId
        }
        
        guard let id = listId else { return [] }
        return await fetchReminders(from: id)
    }
    
    // MARK: - Reminder Actions
    
    func completeReminder(_ reminder: EKReminder) async throws {
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }
    
    func uncompleteReminder(_ reminder: EKReminder) async throws {
        reminder.isCompleted = false
        reminder.completionDate = nil
        try eventStore.save(reminder, commit: true)
    }
}

// MARK: - Reminder Extensions

extension EKReminder {
    var displayTitle: String {
        return title ?? "Untitled"
    }
    
    var hasDueDate: Bool {
        return dueDateComponents != nil
    }
    
    var dueDate: Date? {
        guard let components = dueDateComponents else { return nil }
        return Calendar.current.date(from: components)
    }
    
    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return due < Date() && !isCompleted
    }
}
