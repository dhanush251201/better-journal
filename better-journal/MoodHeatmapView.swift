//
//  MoodHeatmapView.swift
//  better-journal
//
//  365-day GitHub-style heatmap grid.
//  Each cell is color-coded by dominant mood using premium gradients.
//  Lazy-loaded by month sections for performance.
//

import SwiftUI

struct MoodHeatmapView: View {
    let days: [HeatmapDay]
    @State private var selectedDay: HeatmapDay?
    @State private var appeared = false

    // 7 rows (Mon–Sun), ~52 columns
    private let rows = 7
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: BJDesign.Spacing.lg) {
            // Header
            Text("Year in Review")
                .font(BJDesign.Typography.title)
                .padding(.horizontal, BJDesign.Spacing.lg)

            // Heatmap grid
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: cellSpacing) {
                    ForEach(weeks, id: \.self) { weekDays in
                        VStack(spacing: cellSpacing) {
                            ForEach(weekDays) { day in
                                heatmapCell(for: day)
                            }
                        }
                    }
                }
                .padding(.horizontal, BJDesign.Spacing.lg)
            }
            .frame(height: CGFloat(rows) * (cellSize + cellSpacing))

            // Day names (left labels)
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { label in
                    Text(label)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
            }
            .padding(.horizontal, BJDesign.Spacing.lg)

            // Month labels
            monthLabels

            // Legend
            legendView
                .padding(.horizontal, BJDesign.Spacing.lg)

            // Selected day overlay
            if let selected = selectedDay {
                selectedDayCard(selected)
                    .padding(.horizontal, BJDesign.Spacing.lg)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            withAnimation(BJAnimation.springGentle) { appeared = true }
        }
    }

    // MARK: - Grid Layout

    /// Group days into weeks (columns of 7)
    private var weeks: [[HeatmapDay]] {
        stride(from: 0, to: days.count, by: rows).map { start in
            Array(days[start..<min(start + rows, days.count)])
        }
    }

    // MARK: - Cell

    private func heatmapCell(for day: HeatmapDay) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(for: day))
            .frame(width: cellSize, height: cellSize)
            .opacity(appeared ? 1.0 : 0)
            .animation(
                .easeInOut(duration: 0.3).delay(Double.random(in: 0...0.8)),
                value: appeared
            )
            .onTapGesture {
                BJHaptic.light()
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedDay = selectedDay?.id == day.id ? nil : day
                }
            }
    }

    // MARK: - Color Philosophy

    private func cellColor(for day: HeatmapDay) -> Color {
        guard let mood = day.mood else {
            return Color(.systemGray5)
        }

        let base = InsightPalette.color(for: mood)
        let intensity = min(1.0, Double(day.intensity) / 10.0)
        return base.opacity(0.3 + intensity * 0.7)
    }

    // MARK: - Month Labels

    private var monthLabels: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let months = extractMonths()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 40) {
                ForEach(months, id: \.self) { month in
                    Text(formatter.string(from: month))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, BJDesign.Spacing.lg)
        }
    }

    private func extractMonths() -> [Date] {
        let cal = Calendar.current
        var months: [Date] = []
        var seen: Set<Int> = []
        for day in days {
            let month = cal.component(.month, from: day.date)
            if !seen.contains(month) {
                seen.insert(month)
                months.append(day.date)
            }
        }
        return months
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: BJDesign.Spacing.md) {
            Text("Less")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            ForEach(1...5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(InsightPalette.joyGold.opacity(Double(level) / 5.0))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Selected Day Card

    private func selectedDayCard(_ day: HeatmapDay) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        return HStack(spacing: BJDesign.Spacing.md) {
            Circle()
                .fill(cellColor(for: day))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: day.date))
                    .font(BJDesign.Typography.headline)
                if let mood = day.mood,
                   let sentiment = Sentiment(rawValue: mood) {
                    Text(sentiment.displayName)
                        .font(BJDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                if day.entryCount > 0 {
                    Text("\(day.entryCount) \(day.entryCount == 1 ? "entry" : "entries")")
                        .font(BJDesign.Typography.moodLabel)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(BJDesign.Spacing.lg)
        .bjGlassCard()
    }
}
