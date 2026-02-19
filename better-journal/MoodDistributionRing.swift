//
//  MoodDistributionRing.swift
//  better-journal
//
//  Circular mood breakdown using Swift Charts SectorMark.
//  Soft gradient fills per emotion, minimal labels (top 3 only).
//  Animated ring buildup on appear.
//

import Charts
import SwiftUI

struct MoodDistributionRing: View {
    let distribution: [MoodAnalyticsStore.MoodDistributionItem]
    @State private var appeared = false

    private var topItems: [MoodAnalyticsStore.MoodDistributionItem] {
        Array(distribution.prefix(6))
    }

    var body: some View {
        VStack(spacing: BJDesign.Spacing.lg) {
            Text("Mood Balance")
                .font(BJDesign.Typography.headline)
                .foregroundStyle(.primary.opacity(0.8))

            ZStack {
                // Ring chart
                Chart(topItems, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", appeared ? item.count : 0),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(InsightPalette.color(for: item.category).gradient)
                    .cornerRadius(4)
                }
                .frame(width: 200, height: 200)
                .animation(.easeInOut(duration: 1.0), value: appeared)

                // Center label
                VStack(spacing: 2) {
                    if let top = distribution.first {
                        let sentiment = Sentiment(rawValue: top.category)
                        Image(systemName: sentiment?.iconName ?? "circle.fill")
                            .font(.title2)
                            .foregroundStyle(InsightPalette.color(for: top.category))
                        Text(sentiment?.displayName ?? top.category.capitalized)
                            .font(BJDesign.Typography.captionBold)
                        Text("\(Int(top.percentage * 100))%")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Mini legend (top 3)
            HStack(spacing: BJDesign.Spacing.lg) {
                ForEach(distribution.prefix(3), id: \.category) { item in
                    legendItem(item)
                }
            }
        }
        .padding(BJDesign.Spacing.xl)
        .bjGlassCard()
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { appeared = true }
        }
    }

    private func legendItem(_ item: MoodAnalyticsStore.MoodDistributionItem) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(InsightPalette.color(for: item.category))
                .frame(width: 8, height: 8)
            Text(Sentiment(rawValue: item.category)?.displayName ?? item.category.capitalized)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
