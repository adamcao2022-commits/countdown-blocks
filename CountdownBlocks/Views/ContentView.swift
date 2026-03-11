import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var countdownManager: CountdownManager
    @StateObject private var remindersService = RemindersService()
    
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(remindersService)
                .tabItem {
                    Label("Countdown", systemImage: "timer")
                }
                .tag(0)
            
            BlocksView()
                .tabItem {
                    Label("Blocks", systemImage: "square.stack.3d.up")
                }
                .tag(1)
            
            DataView()
                .tabItem {
                    Label("Data", systemImage: "chart.bar")
                }
                .tag(2)
            
            SettingsView()
                .environmentObject(remindersService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .preferredColorScheme(countdownManager.settings?.isDarkMode == true ? .dark : nil)
        .onAppear {
            countdownManager.configure(with: modelContext)
            
            // Check if onboarding needed
            if countdownManager.settings?.firstLaunchDate == Date() {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .environmentObject(remindersService)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CountdownManager())
        .modelContainer(for: [Countdown.self, UserSettings.self, DailyStats.self])
}
