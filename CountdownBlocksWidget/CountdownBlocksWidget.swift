import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Entry

struct CountdownEntry: TimelineEntry {
    let date: Date
    let title: String
    let targetDate: Date?  // For Text(date, style: .timer)
    let type: String
    let isPaused: Bool
}

// MARK: - Timeline Provider

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(
            date: Date(),
            title: "Morning Free Time",
            targetDate: Date().addingTimeInterval(90 * 60),
            type: "morningFreeTime",
            isPaused: false
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        let entry = CountdownEntry(
            date: Date(),
            title: "Work",
            targetDate: Date().addingTimeInterval(135 * 60),
            type: "work",
            isPaused: false
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let entry = loadActiveCountdown()
        
        // With Text(date, style: .timer), we don't need frequent refreshes
        // Only refresh when countdown ends or every 15 minutes for status updates
        let refreshDate: Date
        if let target = entry.targetDate, target > Date() {
            // Refresh when countdown ends
            refreshDate = target.addingTimeInterval(1)
        } else {
            // No active countdown, check again in 15 minutes
            refreshDate = Date().addingTimeInterval(15 * 60)
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadActiveCountdown() -> CountdownEntry {
        let appGroupId = "group.com.countdownblocks.shared"
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return noActiveEntry()
        }
        
        guard let title = defaults.string(forKey: "activeCountdownTitle"),
              let type = defaults.string(forKey: "activeCountdownType") else {
            return noActiveEntry()
        }
        
        let targetDate = defaults.object(forKey: "activeCountdownTargetDate") as? Date
        let isPaused = defaults.bool(forKey: "activeCountdownIsPaused")
        
        return CountdownEntry(
            date: Date(),
            title: title,
            targetDate: targetDate,
            type: type,
            isPaused: isPaused
        )
    }
    
    private func noActiveEntry() -> CountdownEntry {
        return CountdownEntry(
            date: Date(),
            title: "No Active Countdown",
            targetDate: nil,
            type: "none",
            isPaused: false
        )
    }
}

// MARK: - Widget Views

struct CountdownWidgetEntryView: View {
    var entry: CountdownEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: CountdownEntry
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundStyle(iconColor)
            
            Text(entry.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            // Live-updating timer using Text(date, style: .timer)
            if let targetDate = entry.targetDate, targetDate > Date() {
                Text(targetDate, style: .timer)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            } else {
                Text("--:--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            if entry.isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var iconName: String {
        switch entry.type {
        case "Wake Up": return "sunrise.fill"
        case "Morning Free Time": return "cup.and.saucer.fill"
        case "Work": return "briefcase.fill"
        case "Evening Free Time": return "house.fill"
        case "Bedtime": return "moon.fill"
        default: return "timer"
        }
    }
    
    private var iconColor: Color {
        switch entry.type {
        case "Wake Up": return .orange
        case "Morning Free Time": return .yellow
        case "Work": return .blue
        case "Evening Free Time": return .purple
        case "Bedtime": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: CountdownEntry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                
                Text("Time Remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Live-updating timer
                if let targetDate = entry.targetDate, targetDate > Date() {
                    Text(targetDate, style: .timer)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text("--:--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var iconName: String {
        switch entry.type {
        case "Wake Up": return "sunrise.fill"
        case "Morning Free Time": return "cup.and.saucer.fill"
        case "Work": return "briefcase.fill"
        case "Evening Free Time": return "house.fill"
        case "Bedtime": return "moon.fill"
        default: return "timer"
        }
    }
    
    private var iconColor: Color {
        switch entry.type {
        case "Wake Up": return .orange
        case "Morning Free Time": return .yellow
        case "Work": return .blue
        case "Evening Free Time": return .purple
        case "Bedtime": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Lock Screen Widgets

struct CircularWidgetView: View {
    let entry: CountdownEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.caption)
                
                if let targetDate = entry.targetDate, targetDate > Date() {
                    Text(targetDate, style: .timer)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                } else {
                    Text("--:--")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        }
    }
}

struct RectangularWidgetView: View {
    let entry: CountdownEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let targetDate = entry.targetDate, targetDate > Date() {
                    Text(targetDate, style: .timer)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text("--:--")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            
            Spacer()
            
            Image(systemName: "timer")
        }
    }
}

struct InlineWidgetView: View {
    let entry: CountdownEntry
    
    var body: some View {
        if let targetDate = entry.targetDate, targetDate > Date() {
            Label {
                Text(targetDate, style: .timer)
            } icon: {
                Text(entry.title)
            }
        } else {
            Text("\(entry.title): --:--")
        }
    }
}

// MARK: - Widget Configuration

struct CountdownBlocksWidget: Widget {
    let kind: String = "CountdownBlocksWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Countdown Blocks")
        .description("See your active countdown at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Widget Bundle (includes Live Activity)

@main
struct CountdownBlocksWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownBlocksWidget()
        CountdownLiveActivity()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    CountdownBlocksWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        title: "Work",
        targetDate: Date().addingTimeInterval(135 * 60),
        type: "Work",
        isPaused: false
    )
}

#Preview(as: .accessoryRectangular) {
    CountdownBlocksWidget()
} timeline: {
    CountdownEntry(
        date: Date(),
        title: "Bedtime",
        targetDate: Date().addingTimeInterval(225 * 60),
        type: "Bedtime",
        isPaused: false
    )
}
