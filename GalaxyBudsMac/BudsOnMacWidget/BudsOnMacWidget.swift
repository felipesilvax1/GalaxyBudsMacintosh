import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct BudsEntry: TimelineEntry {
    let date: Date
    let leftBattery: Int
    let rightBattery: Int
    let caseBattery: Int
    let deviceName: String
    let isConnected: Bool
}

// MARK: - Timeline Provider
struct BudsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudsEntry {
        BudsEntry(date: .now, leftBattery: 85, rightBattery: 90, caseBattery: 70, deviceName: "Galaxy Buds", isConnected: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BudsEntry) -> Void) {
        let entry = BudsEntry(
            date: .now,
            leftBattery: BudsData.leftBattery,
            rightBattery: BudsData.rightBattery,
            caseBattery: BudsData.caseBattery,
            deviceName: BudsData.deviceName,
            isConnected: BudsData.isConnected
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BudsEntry>) -> Void) {
        let entry = BudsEntry(
            date: .now,
            leftBattery: BudsData.leftBattery,
            rightBattery: BudsData.rightBattery,
            caseBattery: BudsData.caseBattery,
            deviceName: BudsData.deviceName,
            isConnected: BudsData.isConnected
        )
        // Refresh a cada 15 minutos
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct BudsWidgetView: View {
    var entry: BudsEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if entry.isConnected {
            VStack(spacing: 8) {
                Text(entry.deviceName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: family == .systemSmall ? 8 : 16) {
                    CircleBattery(label: "L", level: entry.leftBattery)
                    CircleBattery(label: "R", level: entry.rightBattery)
                    CircleBattery(label: "Case", level: entry.caseBattery)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "earbuds")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - Circular Battery Indicator
struct CircleBattery: View {
    let label: String
    let level: Int
    
    private var color: Color {
        if level > 50 { return .green }
        if level > 20 { return .yellow }
        return .red
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(max(level, 0)) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(level)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .frame(width: 44, height: 44)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Configuration
struct BudsOnMacWidget: Widget {
    let kind = "BudsOnMacWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudsTimelineProvider()) { entry in
            BudsWidgetView(entry: entry)
        }
        .configurationDisplayName("Buds Battery")
        .description("Shows battery levels for your earbuds.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle (entry point)
@main
struct BudsOnMacWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudsOnMacWidget()
    }
}
