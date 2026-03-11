import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @EnvironmentObject private var remindersService: RemindersService
    
    @State private var showingCustomCountdown = false
    @State private var currentReminders: [EKReminder] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Active Countdown Card
                    if let active = countdownManager.activeCountdown {
                        ActiveCountdownCard(countdown: active)
                    } else {
                        NoActiveCountdownView()
                    }
                    
                    // Sleep Preview (when bedtime is active)
                    if countdownManager.activeCountdown?.type == .bedtime,
                       let settings = countdownManager.settings {
                        SleepPreviewCard(settings: settings)
                    }
                    
                    // Current Time Block Reminders
                    if !currentReminders.isEmpty {
                        RemindersSection(reminders: currentReminders)
                    }
                    
                    // Quick Actions
                    QuickActionsSection(showingCustomCountdown: $showingCustomCountdown)
                }
                .padding()
            }
            .navigationTitle("Countdown")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomCountdown = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingCustomCountdown) {
                CustomCountdownSheet()
            }
            .task {
                await loadReminders()
            }
        }
    }
    
    private func loadReminders() async {
        guard let settings = countdownManager.settings,
              let active = countdownManager.activeCountdown else { return }
        
        let block: TimeBlock
        switch active.type {
        case .wakeUp, .morningFreeTime:
            block = .morning
        case .work:
            block = .workday
        case .eveningFreeTime, .bedtime:
            block = .evening
        case .custom:
            return
        }
        
        currentReminders = await remindersService.fetchRemindersForTimeBlock(
            block,
            morningListId: settings.morningReminderListId,
            workdayListId: settings.workdayReminderListId,
            eveningListId: settings.eveningReminderListId
        )
    }
}

// MARK: - Active Countdown Card

struct ActiveCountdownCard: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    let countdown: Countdown
    
    @State private var timeRemaining: String = ""
    
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(countdown.title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Time Remaining
            Text(timeRemaining)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            // Progress Ring (optional visual)
            if countdown.isPaused {
                Label("Paused", systemImage: "pause.circle.fill")
                    .foregroundStyle(.orange)
            }
            
            // Action Buttons
            HStack(spacing: 20) {
                if countdown.isPaused {
                    Button {
                        countdownManager.resumeCountdown(countdown)
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        countdownManager.pauseCountdown(countdown)
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    countdownManager.skipCountdown(countdown)
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            updateTime()
        }
        .onReceive(timer) { _ in
            updateTime()
        }
    }
    
    private func updateTime() {
        timeRemaining = countdown.formattedTimeRemaining
    }
}

// MARK: - No Active Countdown

struct NoActiveCountdownView: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Active Countdown")
                .font(.headline)
            
            Text("Start your first block to begin")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let first = countdownManager.countdowns.first {
                Button {
                    countdownManager.startCountdown(first)
                } label: {
                    Label("Start \(first.title)", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Sleep Preview Card

struct SleepPreviewCard: View {
    let settings: UserSettings
    
    var body: some View {
        let sleepHours = settings.hoursOfSleep(for: DayOfWeek.today)
        
        HStack {
            Image(systemName: "moon.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            
            VStack(alignment: .leading) {
                Text("Sleep Preview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(String(format: "%.1f hours", sleepHours))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Reminders Section

import EventKit

struct RemindersSection: View {
    let reminders: [EKReminder]
    @EnvironmentObject private var remindersService: RemindersService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks")
                .font(.headline)
            
            ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                ReminderRow(reminder: reminder)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ReminderRow: View {
    let reminder: EKReminder
    @EnvironmentObject private var remindersService: RemindersService
    @State private var isCompleted = false
    
    var body: some View {
        HStack {
            Button {
                Task {
                    try? await remindersService.completeReminder(reminder)
                    isCompleted = true
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            
            Text(reminder.displayTitle)
                .strikethrough(isCompleted)
                .foregroundStyle(isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if reminder.isOverdue {
                Text("Overdue")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Quick Actions

struct QuickActionsSection: View {
    @Binding var showingCustomCountdown: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "5 min",
                    icon: "5.circle",
                    duration: 5 * 60
                )
                
                QuickActionButton(
                    title: "15 min",
                    icon: "15.circle",
                    duration: 15 * 60
                )
                
                QuickActionButton(
                    title: "30 min",
                    icon: "30.circle",
                    duration: 30 * 60
                )
                
                QuickActionButton(
                    title: "Custom",
                    icon: "plus.circle",
                    duration: nil
                ) {
                    showingCustomCountdown = true
                }
            }
        }
    }
}

struct QuickActionButton: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    
    let title: String
    let icon: String
    let duration: TimeInterval?
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button {
            if let action = action {
                action()
            } else if let duration = duration {
                countdownManager.createCustomCountdown(title: "\(title) Timer", duration: duration)
            }
        } label: {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Custom Countdown Sheet

struct CustomCountdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var countdownManager: CountdownManager
    
    @State private var title = ""
    @State private var hours = 0
    @State private var minutes = 30
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Countdown name", text: $title)
                }
                
                Section("Duration") {
                    Stepper("\(hours) hours", value: $hours, in: 0...23)
                    Stepper("\(minutes) minutes", value: $minutes, in: 0...59)
                }
            }
            .navigationTitle("Custom Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let duration = TimeInterval(hours * 3600 + minutes * 60)
                        let name = title.isEmpty ? "\(hours)h \(minutes)m Timer" : title
                        countdownManager.createCustomCountdown(title: name, duration: duration)
                        dismiss()
                    }
                    .disabled(hours == 0 && minutes == 0)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(CountdownManager())
        .environmentObject(RemindersService())
}
