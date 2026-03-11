import SwiftUI
import SwiftData
import Charts

struct DataView: View {
    @EnvironmentObject private var countdownManager: CountdownManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var stats: [DailyStats] = []
    @State private var aggregate: StatsAggregate?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(StatsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Active Days Counter
                    if let settings = countdownManager.settings {
                        ActiveDaysCard(totalDays: settings.totalActiveDays)
                    }
                    
                    // Stats Cards
                    if let agg = aggregate {
                        StatsGrid(aggregate: agg)
                    }
                    
                    // Charts
                    if !stats.isEmpty {
                        ChartsSection(stats: stats, period: selectedPeriod)
                    }
                }
                .padding()
            }
            .navigationTitle("Data")
            .onAppear {
                loadStats()
            }
            .onChange(of: selectedPeriod) { _, _ in
                loadStats()
            }
        }
    }
    
    private func loadStats() {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch selectedPeriod {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.date >= startDate },
            sortBy: [SortDescriptor(\.date)]
        )
        
        stats = (try? modelContext.fetch(descriptor)) ?? []
        aggregate = StatsAggregate(period: selectedPeriod, stats: stats)
    }
}

// MARK: - Active Days Card

struct ActiveDaysCard: View {
    let totalDays: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Active Days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\(totalDays)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Stats Grid

struct StatsGrid: View {
    let aggregate: StatsAggregate
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Sleep",
                value: formatHours(aggregate.averageSleepHours),
                icon: "moon.fill",
                color: .indigo
            )
            
            StatCard(
                title: "Work",
                value: formatHours(aggregate.averageWorkHours),
                icon: "briefcase.fill",
                color: .blue
            )
            
            StatCard(
                title: "Morning Free",
                value: formatHours(aggregate.averageMorningFreeTimeHours),
                icon: "sunrise.fill",
                color: .orange
            )
            
            StatCard(
                title: "Evening Free",
                value: formatHours(aggregate.averageEveningFreeTimeHours),
                icon: "house.fill",
                color: .purple
            )
        }
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Charts Section

struct ChartsSection: View {
    let stats: [DailyStats]
    let period: StatsPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends")
                .font(.headline)
            
            // Sleep Chart
            ChartCard(title: "Sleep") {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Hours", stat.hoursSlept)
                    )
                    .foregroundStyle(.indigo)
                }
                .frame(height: 150)
            }
            
            // Work Chart
            ChartCard(title: "Work") {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Date", stat.date, unit: .day),
                        y: .value("Hours", stat.hoursWorked)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 150)
            }
            
            // Free Time Chart (stacked)
            ChartCard(title: "Free Time") {
                Chart {
                    ForEach(stats) { stat in
                        BarMark(
                            x: .value("Date", stat.date, unit: .day),
                            y: .value("Hours", stat.morningFreeTimeHours)
                        )
                        .foregroundStyle(by: .value("Type", "Morning"))
                        
                        BarMark(
                            x: .value("Date", stat.date, unit: .day),
                            y: .value("Hours", stat.eveningFreeTimeHours)
                        )
                        .foregroundStyle(by: .value("Type", "Evening"))
                    }
                }
                .chartForegroundStyleScale([
                    "Morning": Color.orange,
                    "Evening": Color.purple
                ])
                .frame(height: 150)
            }
        }
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            content
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DataView()
        .environmentObject(CountdownManager())
        .modelContainer(for: DailyStats.self)
}
