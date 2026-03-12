import SwiftUI
import SwiftData
import EventKit

struct SettingsView: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @EnvironmentObject private var remindersService: RemindersService
    
    var body: some View {
        NavigationStack {
            Form {
                // Sleep Schedule Section
                Section("Sleep Schedule") {
                    HealthKitSleepSection()
                }
                
                // Schedule Section
                Section("Default Schedule") {
                    if let settings = countdownManager.settings {
                        ScheduleEditor(settings: settings)
                    }
                }
                
                // Per-Day Customization
                Section("Day Customization") {
                    NavigationLink("Customize by Day") {
                        DayCustomizationView()
                    }
                }
                
                // Reminders Integration
                Section("Reminders Integration") {
                    RemindersSettingsSection()
                }
                
                // Appearance
                Section("Appearance") {
                    if let settings = countdownManager.settings {
                        Toggle("Dark Mode", isOn: Binding(
                            get: { settings.isDarkMode },
                            set: { settings.isDarkMode = $0 }
                        ))
                    }
                }
                
                // Notifications
                Section("Notifications") {
                    if let settings = countdownManager.settings {
                        Toggle("Enable Notifications", isOn: Binding(
                            get: { settings.notificationsEnabled },
                            set: { settings.notificationsEnabled = $0 }
                        ))
                        
                        Toggle("Haptic Feedback", isOn: Binding(
                            get: { settings.hapticFeedbackEnabled },
                            set: { settings.hapticFeedbackEnabled = $0 }
                        ))
                    }
                }
                
                // History
                Section("History") {
                    NavigationLink("Custom Countdown History") {
                        HistoryView()
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    if let settings = countdownManager.settings {
                        HStack {
                            Text("Active Since")
                            Spacer()
                            Text(settings.firstLaunchDate, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - HealthKit Sleep Section

struct HealthKitSleepSection: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @StateObject private var healthKitService = HealthKitService.shared
    @State private var isConnecting = false
    
    var body: some View {
        if healthKitService.isAuthorized {
            // Show detected sleep schedule
            if let schedule = countdownManager.sleepSchedule {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    
                    VStack(alignment: .leading) {
                        Text("Wake Time (from Health)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(schedule.formattedWakeTime)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Text("Based on \(schedule.sampleCount) nights")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let bedtime = schedule.formattedBedtime {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(.indigo)
                        
                        VStack(alignment: .leading) {
                            Text("Bedtime (from Health)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(bedtime)
                                .font(.headline)
                        }
                    }
                }
                
                Button("Refresh Sleep Data") {
                    Task {
                        await countdownManager.requestHealthKitAccess()
                    }
                }
                .font(.caption)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Connected to Health")
                }
                
                Text("Sleep data will appear after a few nights of tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Apple Health")
                        .font(.headline)
                }
                
                Text("Auto-detect your wake time from your sleep schedule")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    isConnecting = true
                    Task {
                        await countdownManager.requestHealthKitAccess()
                        isConnecting = false
                    }
                } label: {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Label("Connect Health", systemImage: "link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
            }
        }
    }
}

// MARK: - Schedule Editor

struct ScheduleEditor: View {
    @Bindable var settings: UserSettings
    
    var body: some View {
        DatePicker(
            "Wake Up Time",
            selection: $settings.wakeUpTime,
            displayedComponents: .hourAndMinute
        )
        
        DatePicker(
            "Work Start",
            selection: $settings.workStartTime,
            displayedComponents: .hourAndMinute
        )
        
        DatePicker(
            "Work End",
            selection: $settings.workEndTime,
            displayedComponents: .hourAndMinute
        )
        
        DatePicker(
            "Bedtime",
            selection: $settings.bedtimeTarget,
            displayedComponents: .hourAndMinute
        )
        
        // Sleep preview
        let sleepHours = settings.hoursOfSleep(for: .monday)
        HStack {
            Text("Sleep Duration")
            Spacer()
            Text(String(format: "%.1f hours", sleepHours))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Day Customization View

struct DayCustomizationView: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @State private var selectedDay: DayOfWeek = .monday
    
    var body: some View {
        Form {
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases) { day in
                    Text(day.shortName).tag(day)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            
            if let settings = countdownManager.settings {
                let schedule = settings.schedule(for: selectedDay)
                
                Section("Schedule for \(selectedDay.shortName)") {
                    DayScheduleRow(
                        label: "Wake Up",
                        time: schedule.wakeUpTime,
                        onChange: { newTime in
                            updateOverride(\.wakeUpTime, to: newTime)
                        }
                    )
                    
                    DayScheduleRow(
                        label: "Work Start",
                        time: schedule.workStartTime,
                        onChange: { newTime in
                            updateOverride(\.workStartTime, to: newTime)
                        }
                    )
                    
                    DayScheduleRow(
                        label: "Work End",
                        time: schedule.workEndTime,
                        onChange: { newTime in
                            updateOverride(\.workEndTime, to: newTime)
                        }
                    )
                    
                    DayScheduleRow(
                        label: "Bedtime",
                        time: schedule.bedtimeTarget,
                        onChange: { newTime in
                            updateOverride(\.bedtimeTarget, to: newTime)
                        }
                    )
                }
                
                Section {
                    Button("Reset to Default") {
                        var overrides = settings.dayOverrides
                        overrides.removeValue(forKey: selectedDay)
                        settings.dayOverrides = overrides
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Day Customization")
    }
    
    private func updateOverride(_ keyPath: WritableKeyPath<DayScheduleOverride, Date?>, to value: Date) {
        guard let settings = countdownManager.settings else { return }
        
        var overrides = settings.dayOverrides
        var override = overrides[selectedDay] ?? DayScheduleOverride()
        override[keyPath: keyPath] = value
        overrides[selectedDay] = override
        settings.dayOverrides = overrides
    }
}

struct DayScheduleRow: View {
    let label: String
    let time: Date
    let onChange: (Date) -> Void
    
    @State private var editedTime: Date
    
    init(label: String, time: Date, onChange: @escaping (Date) -> Void) {
        self.label = label
        self.time = time
        self.onChange = onChange
        self._editedTime = State(initialValue: time)
    }
    
    var body: some View {
        DatePicker(
            label,
            selection: $editedTime,
            displayedComponents: .hourAndMinute
        )
        .onChange(of: editedTime) { _, newValue in
            onChange(newValue)
        }
    }
}

// MARK: - Reminders Settings

struct RemindersSettingsSection: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @EnvironmentObject private var remindersService: RemindersService
    
    var body: some View {
        if remindersService.isAuthorized {
            if let settings = countdownManager.settings {
                ReminderListPicker(
                    label: "Morning Tasks",
                    selection: Binding(
                        get: { settings.morningReminderListId },
                        set: { settings.morningReminderListId = $0 }
                    ),
                    lists: remindersService.reminderLists
                )
                
                ReminderListPicker(
                    label: "Workday Tasks",
                    selection: Binding(
                        get: { settings.workdayReminderListId },
                        set: { settings.workdayReminderListId = $0 }
                    ),
                    lists: remindersService.reminderLists
                )
                
                ReminderListPicker(
                    label: "Evening Tasks",
                    selection: Binding(
                        get: { settings.eveningReminderListId },
                        set: { settings.eveningReminderListId = $0 }
                    ),
                    lists: remindersService.reminderLists
                )
            }
        } else {
            Button("Connect Reminders") {
                Task {
                    await remindersService.requestAccess()
                }
            }
            
            Text("Connect to see tasks during each time block")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ReminderListPicker: View {
    let label: String
    @Binding var selection: String?
    let lists: [EKCalendar]
    
    var body: some View {
        Picker(label, selection: $selection) {
            Text("None").tag(nil as String?)
            
            ForEach(lists, id: \.calendarIdentifier) { list in
                Text(list.title).tag(list.calendarIdentifier as String?)
            }
        }
    }
}

// MARK: - History View

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CountdownHistory.startedAt, order: .reverse)
    private var history: [CountdownHistory]
    
    var body: some View {
        List {
            if history.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Custom countdowns will appear here")
                )
            } else {
                ForEach(history) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                        
                        HStack {
                            Text("\(item.durationMinutes) min")
                            Text("•")
                            Text(item.startedAt, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(history[index])
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !history.isEmpty {
                EditButton()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CountdownManager())
        .environmentObject(RemindersService())
}
