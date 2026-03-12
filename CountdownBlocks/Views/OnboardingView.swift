import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var countdownManager: CountdownManager
    @EnvironmentObject private var remindersService: RemindersService
    
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)
                
                HowItWorksPage()
                    .tag(1)
                
                ScheduleSetupPage()
                    .tag(2)
                
                IntegrationsPage()
                    .tag(3)
                
                ReadyPage()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Navigation Buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentPage < 4 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .interactiveDismissDisabled(currentPage < 4)
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Welcome to\nCountdown Blocks")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Structure your day with sequential\ncountdown timers")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - How It Works Page

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "timer",
                    title: "Sequential Timers",
                    description: "Your day flows from one block to the next automatically"
                )
                
                FeatureRow(
                    icon: "bell.fill",
                    title: "Smart Notifications",
                    description: "Get notified when each block ends, then start the next"
                )
                
                FeatureRow(
                    icon: "rectangle.on.rectangle",
                    title: "Home Screen Widget",
                    description: "Always see your active countdown at a glance"
                )
                
                FeatureRow(
                    icon: "chart.bar.fill",
                    title: "Automatic Tracking",
                    description: "See your sleep, work, and free time trends over time"
                )
            }
            
            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Schedule Setup Page

struct ScheduleSetupPage: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Set Your Schedule")
                .font(.title)
                .fontWeight(.bold)
            
            Text("We'll create your daily blocks based on these times")
                .foregroundStyle(.secondary)
            
            if let settings = countdownManager.settings {
                ScheduleSetupContent(settings: settings)
            }
            
            Text("You can customize times per day later in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

struct ScheduleSetupContent: View {
    @Bindable var settings: UserSettings
    
    var body: some View {
        VStack(spacing: 16) {
            ScheduleTimeRow(
                icon: "sunrise.fill",
                color: .orange,
                label: "Wake Up",
                time: $settings.wakeUpTime
            )
            
            ScheduleTimeRow(
                icon: "briefcase.fill",
                color: .blue,
                label: "Work Start",
                time: $settings.workStartTime
            )
            
            ScheduleTimeRow(
                icon: "briefcase",
                color: .blue,
                label: "Work End",
                time: $settings.workEndTime
            )
            
            ScheduleTimeRow(
                icon: "moon.fill",
                color: .indigo,
                label: "Bedtime",
                time: $settings.bedtimeTarget
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ScheduleTimeRow: View {
    let icon: String
    let color: Color
    let label: String
    @Binding var time: Date
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(label)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }
}

// MARK: - Integrations Page

struct IntegrationsPage: View {
    @EnvironmentObject private var remindersService: RemindersService
    @State private var remindersConnected = false
    @State private var notificationsEnabled = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Connect Your Apps")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Countdown Blocks works even better with these integrations")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                IntegrationRow(
                    icon: "checklist",
                    title: "Reminders",
                    description: "See tasks during each time block",
                    isConnected: remindersConnected
                ) {
                    Task {
                        remindersConnected = await remindersService.requestAccess()
                    }
                }
                
                IntegrationRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get alerted when countdowns end",
                    isConnected: notificationsEnabled
                ) {
                    // Notifications already requested in app init
                    notificationsEnabled = true
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            VStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                
                Text("Note: iOS doesn't allow reading Clock alarms directly.\nYou'll enter your wake-up time manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            remindersConnected = remindersService.isAuthorized
        }
    }
}

struct IntegrationRow: View {
    let icon: String
    let title: String
    let description: String
    let isConnected: Bool
    let onConnect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Ready Page

struct ReadyPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your daily countdown blocks are ready.\nStart your first block to begin!")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(text: "Add the widget to your home screen for quick access")
                TipRow(text: "Tap a countdown to pause, skip, or edit it")
                TipRow(text: "Check the Data tab to see your trends")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .padding()
    }
}

struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(CountdownManager())
        .environmentObject(RemindersService())
}
