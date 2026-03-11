import ActivityKit
import WidgetKit
import SwiftUI

// Import shared attributes from main app
struct CountdownActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isPaused: Bool
        var sleepHours: Double?
    }
    
    var title: String
    var type: String
    var targetDate: Date
    var iconName: String
}

// MARK: - Live Activity Widget

struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.iconName)
                            .foregroundStyle(iconColor(for: context.attributes.type))
                        Text(context.attributes.title)
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.targetDate, style: .timer)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(context.state.isPaused ? .secondary : .primary)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if let sleepHours = context.state.sleepHours {
                        HStack {
                            Image(systemName: "bed.double.fill")
                            Text(String(format: "%.1f hours of sleep", sleepHours))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading (pill left side)
                Image(systemName: context.attributes.iconName)
                    .foregroundStyle(iconColor(for: context.attributes.type))
            } compactTrailing: {
                // Compact trailing (pill right side)
                Text(context.attributes.targetDate, style: .timer)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .frame(minWidth: 40)
            } minimal: {
                // Minimal (when multiple activities)
                Image(systemName: context.attributes.iconName)
                    .foregroundStyle(iconColor(for: context.attributes.type))
            }
        }
    }
    
    private func iconColor(for type: String) -> Color {
        switch type {
        case "Wake Up": return .orange
        case "Morning Free Time": return .yellow
        case "Work": return .blue
        case "Evening Free Time": return .purple
        case "Bedtime": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<CountdownActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: context.attributes.iconName)
                .font(.title)
                .foregroundStyle(iconColor)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                
                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let sleepHours = context.state.sleepHours {
                    Text(String(format: "%.1f hrs sleep", sleepHours))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Timer
            Text(context.attributes.targetDate, style: .timer)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(context.state.isPaused ? .secondary : .primary)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }
    
    private var iconColor: Color {
        switch context.attributes.type {
        case "Wake Up": return .orange
        case "Morning Free Time": return .yellow
        case "Work": return .blue
        case "Evening Free Time": return .purple
        case "Bedtime": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview("Live Activity", as: .content, using: CountdownActivityAttributes(
    title: "Work",
    type: "Work",
    targetDate: Date().addingTimeInterval(2 * 60 * 60),
    iconName: "briefcase.fill"
)) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(isPaused: false, sleepHours: nil)
    CountdownActivityAttributes.ContentState(isPaused: true, sleepHours: nil)
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: CountdownActivityAttributes(
    title: "Bedtime",
    type: "Bedtime",
    targetDate: Date().addingTimeInterval(3 * 60 * 60),
    iconName: "moon.fill"
)) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(isPaused: false, sleepHours: 7.5)
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: CountdownActivityAttributes(
    title: "Evening Free Time",
    type: "Evening Free Time",
    targetDate: Date().addingTimeInterval(90 * 60),
    iconName: "house.fill"
)) {
    CountdownLiveActivity()
} contentStates: {
    CountdownActivityAttributes.ContentState(isPaused: false, sleepHours: nil)
}
