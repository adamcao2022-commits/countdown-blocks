# Countdown Blocks

A native iOS app that helps users structure their day using sequential, recurring countdown timers displayed as home screen and lock screen widgets.

## Features

### MVP Features
- **Recurring Countdowns** - Daily blocks that repeat automatically
- **Sequential Chain** - When one countdown ends, prompts for the next
- **Per-Day Customization** - Different schedules for weekdays vs weekends
- **Custom Countdowns** - One-off timers with history
- **Real-Time Adjustments** - Edit on the fly with scope options
- **Pause & Skip** - Flexibility when plans change

### Integrations
- **Reminders App** - Link reminder lists to time blocks (Morning/Work/Evening)
- **HealthKit Sleep** - Auto-detect wake time from your sleep schedule 🆕
- **Sleep Tracking** - Calculate sleep hours from bedtime to wake time

### Live Activities & Dynamic Island 🆕
- **Dynamic Island** - See countdown in compact pill or expanded view
- **Lock Screen Banner** - Persistent countdown without opening app
- **Real-time updates** - Timer updates live using `Text(date, style: .timer)`

### Widgets
- **Home Screen** - Small and medium widgets with live-updating timers
- **Lock Screen** - Circular, rectangular, and inline widgets
- **Battery Efficient** - Uses `Text(date, style: .timer)` for system-managed updates

### Data & Analytics
- Hours slept, worked, and free time
- Day/week/month/year views
- Total active days counter
- All data collected automatically from countdown usage

## Technical Stack

- **SwiftUI** - Modern declarative UI
- **SwiftData** - Persistence layer
- **WidgetKit** - Home screen and lock screen widgets
- **ActivityKit** - Live Activities & Dynamic Island 🆕
- **HealthKit** - Sleep schedule detection 🆕
- **EventKit** - Reminders integration
- **UserNotifications** - Countdown alerts

## Project Structure

```
CountdownBlocks/
├── CountdownBlocksApp.swift          # App entry point
├── Models/
│   ├── Countdown.swift               # Core countdown model
│   ├── UserSettings.swift            # User preferences
│   ├── DailyStats.swift              # Analytics data
│   └── CountdownActivityAttributes.swift  # Live Activity attributes
├── ViewModels/
│   └── CountdownManager.swift        # Main state management
├── Views/
│   ├── ContentView.swift             # Tab container
│   ├── HomeView.swift                # Active countdown display
│   ├── BlocksView.swift              # Manage countdown blocks
│   ├── DataView.swift                # Analytics & charts
│   ├── SettingsView.swift            # App settings
│   └── OnboardingView.swift          # First-run tutorial
├── Services/
│   ├── RemindersService.swift        # EventKit integration
│   ├── WidgetService.swift           # Widget data sharing
│   ├── LiveActivityService.swift     # Live Activities management
│   ├── HealthKitService.swift        # HealthKit sleep integration
│   └── NotificationService.swift     # Notification handling

CountdownBlocksWidget/
├── CountdownBlocksWidget.swift       # Home/lock screen widgets
└── CountdownLiveActivity.swift       # Dynamic Island & Live Activity
```

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode → File → New → Project
2. Select **App** under iOS
3. Settings:
   - Product Name: `Countdown Blocks`
   - Bundle Identifier: `com.yourname.countdownblocks`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**

### 2. Add Widget Extension

1. File → New → Target
2. Select **Widget Extension**
3. Name: `CountdownBlocksWidget`
4. Uncheck "Include Configuration App Intent"

### 3. Configure App Group

1. Select the main app target → Signing & Capabilities
2. Add **App Groups** capability
3. Create group: `group.com.countdownblocks.shared`
4. Do the same for the widget extension target

### 4. Add Required Capabilities

**Main App:**
- App Groups
- Background Modes (Background fetch, Remote notifications)

**Entitlements (Info.plist):**
```xml
<key>NSRemindersUsageDescription</key>
<string>Countdown Blocks shows your tasks during each time block.</string>
```

### 5. Import Source Files

Copy all `.swift` files from this repository into the Xcode project:
- Main app files go in `CountdownBlocks/`
- Widget files go in `CountdownBlocksWidget/`

### 6. Build & Run

1. Select an iOS 17+ simulator or device
2. Build and run (⌘R)

## Default Daily Flow

1. **Wake Up** - Countdown to your alarm time
2. **Morning Free Time** - Alarm to work start
3. **Work** - Work start to work end
4. **Evening Free Time** - Work end to bedtime
5. **Bedtime** - Shows hours of sleep until wake time

## Monetization

Free app, no ads, no in-app purchases (MVP).

---

## Development Notes

### iOS Limitations

- **Clock/Alarm Access**: iOS does not provide API access to read alarms from the Clock app. Users must manually enter their wake-up time.
- **HealthKit Alternative**: Could integrate with Health app's sleep schedule for automatic wake time detection (optional enhancement).

### Widget Updates

Widgets update every minute via `TimelineProvider`. The main app writes to shared `UserDefaults` (App Group), and the widget reads from it.

### Future Enhancements

- Apple Watch app
- HealthKit sleep integration
- Focus mode integration
- Shortcuts support
- iCloud sync
