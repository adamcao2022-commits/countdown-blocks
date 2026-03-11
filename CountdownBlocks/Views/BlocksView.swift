import SwiftUI

struct BlocksView: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @State private var selectedCountdown: Countdown?
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Daily Blocks") {
                    ForEach(recurringCountdowns) { countdown in
                        BlockRow(countdown: countdown)
                            .onTapGesture {
                                selectedCountdown = countdown
                                showingEditSheet = true
                            }
                    }
                    .onMove { from, to in
                        // Reorder countdowns
                        var mutable = recurringCountdowns
                        mutable.move(fromOffsets: from, toOffset: to)
                        for (index, countdown) in mutable.enumerated() {
                            countdown.order = index
                        }
                    }
                }
                
                if !customCountdowns.isEmpty {
                    Section("Custom Countdowns") {
                        ForEach(customCountdowns) { countdown in
                            BlockRow(countdown: countdown)
                                .onTapGesture {
                                    selectedCountdown = countdown
                                    showingEditSheet = true
                                }
                        }
                        .onDelete { indexSet in
                            // Delete custom countdowns
                            for index in indexSet {
                                let countdown = customCountdowns[index]
                                countdownManager.countdowns.removeAll { $0.id == countdown.id }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Blocks")
            .toolbar {
                EditButton()
            }
            .sheet(isPresented: $showingEditSheet) {
                if let countdown = selectedCountdown {
                    EditBlockSheet(countdown: countdown)
                }
            }
        }
    }
    
    private var recurringCountdowns: [Countdown] {
        countdownManager.countdowns
            .filter { $0.isRecurring }
            .sorted { $0.order < $1.order }
    }
    
    private var customCountdowns: [Countdown] {
        countdownManager.countdowns
            .filter { !$0.isRecurring }
            .sorted { ($0.createdAt) > ($1.createdAt) }
    }
}

// MARK: - Block Row

struct BlockRow: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    let countdown: Countdown
    
    var body: some View {
        HStack {
            // Icon based on type
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(countdown.title)
                    .font(.headline)
                
                if countdown.isActive {
                    Text(countdown.formattedTimeRemaining)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                } else if let time = countdown.targetTime(for: DayOfWeek.today) {
                    Text(time, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if countdown.isActive {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.green)
            } else if countdown.isPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
            }
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var iconName: String {
        switch countdown.type {
        case .wakeUp: return "sunrise.fill"
        case .morningFreeTime: return "cup.and.saucer.fill"
        case .work: return "briefcase.fill"
        case .eveningFreeTime: return "house.fill"
        case .bedtime: return "moon.fill"
        case .custom: return "timer"
        }
    }
    
    private var iconColor: Color {
        switch countdown.type {
        case .wakeUp: return .orange
        case .morningFreeTime: return .yellow
        case .work: return .blue
        case .eveningFreeTime: return .purple
        case .bedtime: return .indigo
        case .custom: return .gray
        }
    }
}

// MARK: - Edit Block Sheet

struct EditBlockSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var countdownManager: CountdownManager
    
    let countdown: Countdown
    
    @State private var title: String = ""
    @State private var selectedDay: DayOfWeek = .today
    @State private var targetTime: Date = Date()
    @State private var showingApplyOptions = false
    @State private var hasChanges = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Block Name") {
                    TextField("Title", text: $title)
                        .onChange(of: title) { _, _ in hasChanges = true }
                }
                
                if countdown.isRecurring {
                    Section("Day of Week") {
                        Picker("Day", selection: $selectedDay) {
                            ForEach(DayOfWeek.allCases) { day in
                                Text(day.shortName).tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedDay) { _, newDay in
                            loadTimeForDay(newDay)
                        }
                    }
                    
                    Section("Target Time") {
                        DatePicker(
                            "End Time",
                            selection: $targetTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: targetTime) { _, _ in hasChanges = true }
                    }
                } else {
                    Section("Duration") {
                        if let minutes = countdown.durationMinutes {
                            let hours = minutes / 60
                            let mins = minutes % 60
                            Text("\(hours)h \(mins)m")
                        }
                    }
                }
                
                Section {
                    if countdown.isActive {
                        Button {
                            countdownManager.pauseCountdown(countdown)
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                        }
                    } else if countdown.isPaused {
                        Button {
                            countdownManager.resumeCountdown(countdown)
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                        }
                    } else {
                        Button {
                            countdownManager.startCountdown(countdown)
                            dismiss()
                        } label: {
                            Label("Start Now", systemImage: "play.fill")
                        }
                    }
                    
                    Button {
                        countdownManager.skipCountdown(countdown)
                        dismiss()
                    } label: {
                        Label("Skip", systemImage: "forward.fill")
                    }
                }
            }
            .navigationTitle("Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showingApplyOptions = true
                    }
                    .disabled(!hasChanges)
                }
            }
            .onAppear {
                title = countdown.title
                loadTimeForDay(selectedDay)
            }
            .confirmationDialog("Apply Changes", isPresented: $showingApplyOptions) {
                Button("Today Only") {
                    saveChanges(scope: .todayOnly)
                }
                
                Button("\(selectedDay.shortName) Going Forward") {
                    saveChanges(scope: .thisDay)
                }
                
                Button("All Days") {
                    saveChanges(scope: .allDays)
                }
                
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to apply this change?")
            }
        }
    }
    
    private func loadTimeForDay(_ day: DayOfWeek) {
        if let time = countdown.targetTime(for: day) {
            targetTime = time
        }
    }
    
    private func saveChanges(scope: CountdownManager.EditScope) {
        countdown.title = title
        countdownManager.editCountdown(countdown, newTime: targetTime, scope: scope)
        dismiss()
    }
}

#Preview {
    BlocksView()
        .environmentObject(CountdownManager())
}
