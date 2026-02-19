//
//  InsightWidgetProvider.swift
//  better-journal
//
//  Widget source files for ambient mood insights.
//  NOTE: These need a Widget Extension target in Xcode to function.
//  Move to the widget target once created.
//
//  Small widget: gradient + micro insight
//  Medium widget: sparkline summary + streak counter
//

import SwiftUI
import WidgetKit

// MARK: - Widget Data (shared via App Group UserDefaults)

struct WidgetMoodData: Codable {
    let dominantMood: String
    let microInsight: String
    let currentStreak: Int
    let weeklyValences: [Double]    // 7 values for sparkline
    let lastUpdated: Date

    static let empty = WidgetMoodData(
        dominantMood: "neutral",
        microInsight: "Start journaling to see insights.",
        currentStreak: 0,
        weeklyValences: [],
        lastUpdated: Date()
    )
}

// MARK: - Widget Data Writer (called from main app)

enum WidgetDataWriter {
    private static let suiteName = "group.com.betterjournal.shared"
    private static let key = "widget_mood_data"

    static func write(_ data: WidgetMoodData) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data)
        else { return }
        defaults.set(encoded, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetMoodData {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetMoodData.self, from: data)
        else { return .empty }
        return decoded
    }
}

// MARK: - Timeline Provider

struct InsightTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> InsightTimelineEntry {
        InsightTimelineEntry(date: Date(), data: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (InsightTimelineEntry) -> Void) {
        completion(InsightTimelineEntry(date: Date(), data: WidgetDataWriter.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InsightTimelineEntry>) -> Void) {
        let data = WidgetDataWriter.read()
        let entry = InsightTimelineEntry(date: Date(), data: data)
        // Refresh every 4 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct InsightTimelineEntry: TimelineEntry {
    let date: Date
    let data: WidgetMoodData
}

// MARK: - Small Widget View

struct SmallInsightWidgetView: View {
    let entry: InsightTimelineEntry

    var body: some View {
        let colors = InsightPalette.gradient(for: entry.data.dominantMood)

        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: Sentiment(rawValue: entry.data.dominantMood)?.iconName ?? "sparkles")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(entry.data.microInsight)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [colors[0].opacity(0.9), colors[1].opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Medium Widget View

struct MediumInsightWidgetView: View {
    let entry: InsightTimelineEntry

    var body: some View {
        let colors = InsightPalette.gradient(for: entry.data.dominantMood)

        HStack(spacing: 16) {
            // Sparkline
            VStack(alignment: .leading, spacing: 6) {
                Text("This Week")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                if !entry.data.weeklyValences.isEmpty {
                    MiniSparkline(values: entry.data.weeklyValences)
                        .frame(height: 40)
                }

                Spacer()

                Text(entry.data.microInsight)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }

            Divider()
                .overlay(Color.white.opacity(0.2))

            // Streak
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("\(entry.data.currentStreak)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("day streak")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 70)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [colors[0].opacity(0.85), colors[1].opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Mini Sparkline (lightweight for widget)

struct MiniSparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let normalized = values.map { ($0 + 1) / 2 }   // [-1,1] → [0,1]
            let step = geo.size.width / max(1, CGFloat(normalized.count - 1))

            Path { path in
                guard !normalized.isEmpty else { return }
                path.move(to: CGPoint(x: 0, y: geo.size.height * (1 - normalized[0])))
                for i in 1..<normalized.count {
                    let x = step * CGFloat(i)
                    let y = geo.size.height * (1 - normalized[i])
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.white.opacity(0.8), lineWidth: 2)
        }
    }
}
