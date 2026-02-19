//
//  WeeklySparklineChart.swift
//  better-journal
//
//  Smooth curved line chart showing 7-day mood intensity.
//  Built with Apple's Swift Charts. Animated drawing path
//  with subtle glow and gradient area fill.
//

import Charts
import SwiftUI

struct WeeklySparklineChart: View {
    let data: [SparklinePoint]
    @State private var appeared = false

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BJDesign.Spacing.sm) {
            Text("This Week")
                .font(BJDesign.Typography.headline)
                .foregroundStyle(.primary.opacity(0.8))

            Chart {
                ForEach(data) { point in
                    // Area fill
                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Mood", appeared ? normalizedValence(point.valence) : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(areaGradient)

                    // Main line
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Mood", appeared ? normalizedValence(point.valence) : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .shadow(
                        color: InsightPalette.joyGold.opacity(0.3),
                        radius: 4, y: 2
                    )

                    // Data points
                    PointMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Mood", appeared ? normalizedValence(point.valence) : 0)
                    )
                    .symbolSize(appeared ? 30 : 0)
                    .foregroundStyle(InsightPalette.color(for: point.mood))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(dayFormatter.string(from: date))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.quaternary)
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 160)
            .animation(.easeInOut(duration: 0.8), value: appeared)
        }
        .padding(BJDesign.Spacing.xl)
        .bjGlassCard()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) { appeared = true }
        }
    }

    // MARK: - Helpers

    /// Normalize valence from [-1, 1] to [0, 1] for chart display
    private func normalizedValence(_ v: Double) -> Double {
        (v + 1.0) / 2.0
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [InsightPalette.joyGold, InsightPalette.calmSky],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                InsightPalette.joyGold.opacity(0.2),
                InsightPalette.calmSky.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
