//
//  WeeklyInsightView.swift
//  better-journal
//

import SwiftUI

/// A beautiful weekly mood dashboard showing a mood ring, bar chart,
/// and AI-generated insight card.
struct WeeklyInsightView: View {
    let summaries: [MoodSummary]
    let insight: String?
    let profile: PersonalityProfile?

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: BJDesign.Spacing.xl) {
                // Header
                VStack(spacing: BJDesign.Spacing.xs) {
                    Text("Your Week")
                        .font(BJDesign.Typography.largeTitle)
                    Text("A reflection of your emotional journey")
                        .font(BJDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, BJDesign.Spacing.xl)

                // Mood Ring
                if !summaries.isEmpty {
                    MoodRingView(
                        averageValence: weekAverageValence,
                        averageArousal: weekAverageArousal
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(appeared ? 1.0 : 0.8)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(BJAnimation.springGentle, value: appeared)
                }

                // Bar Chart
                if !summaries.isEmpty {
                    moodBarChart
                        .padding(.horizontal, BJDesign.Spacing.lg)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(BJAnimation.springGentle.delay(0.15), value: appeared)
                }

                // AI Insight Card
                if let insight {
                    insightCard(insight)
                        .padding(.horizontal, BJDesign.Spacing.lg)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(BJAnimation.springGentle.delay(0.3), value: appeared)
                }

                // Personality Traits
                if let profile, !profile.dominantTraits.isEmpty {
                    traitsCard(profile)
                        .padding(.horizontal, BJDesign.Spacing.lg)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(BJAnimation.springGentle.delay(0.45), value: appeared)
                }

                Spacer(minLength: 40)
            }
        }
        .background(MoodGradientBackground(moodScore: nil))
        .onAppear { appeared = true }
    }

    // MARK: - Computed

    private var weekAverageValence: Double {
        guard !summaries.isEmpty else { return 0 }
        return summaries.map(\.averageValence).reduce(0, +) / Double(summaries.count)
    }

    private var weekAverageArousal: Double {
        guard !summaries.isEmpty else { return 0.3 }
        return summaries.map(\.averageArousal).reduce(0, +) / Double(summaries.count)
    }

    private var maxEntryCount: Int {
        summaries.map(\.entryCount).max() ?? 1
    }

    // MARK: - Bar Chart

    private var moodBarChart: some View {
        VStack(spacing: BJDesign.Spacing.sm) {
            Text("Daily Mood")
                .font(BJDesign.Typography.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(summaries.suffix(7).enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barGradient(for: day))
                            .frame(width: 32, height: barHeight(for: day))
                            .scaleEffect(y: appeared ? 1.0 : 0, anchor: .bottom)
                            .animation(
                                BJAnimation.springEntry.delay(Double(index) * BJAnimation.staggerDelay),
                                value: appeared
                            )

                        Text(day.dayLabel)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .padding()
            .bjCard()
        }
    }

    private func barHeight(for summary: MoodSummary) -> CGFloat {
        let normalizedValence = (summary.averageValence + 1.0) / 2.0  // [0, 1]
        return max(12, CGFloat(normalizedValence) * 100)
    }

    private func barGradient(for summary: MoodSummary) -> LinearGradient {
        let sentiment = Sentiment(rawValue: summary.dominantSentiment) ?? .neutral
        return LinearGradient(
            colors: [sentiment.color, sentiment.color.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Insight Card

    private func insightCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: BJDesign.Spacing.md) {
            Label("Weekly Insight", systemImage: "brain.head.profile.fill")
                .font(BJDesign.Typography.headline)
                .foregroundStyle(.purple)

            Text(text)
                .font(BJDesign.Typography.body)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BJDesign.Spacing.xl)
        .bjCard()
    }

    // MARK: - Traits Card

    private func traitsCard(_ profile: PersonalityProfile) -> some View {
        VStack(alignment: .leading, spacing: BJDesign.Spacing.md) {
            Label("Your Patterns", systemImage: "sparkles")
                .font(BJDesign.Typography.headline)
                .foregroundStyle(.orange)

            // Dominant trait tags
            if !profile.dominantTraits.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(profile.dominantTraits, id: \.self) { trait in
                        if let sentiment = Sentiment(rawValue: trait) {
                            SentimentTagView(sentiment: sentiment)
                        } else {
                            Text(trait.capitalized)
                                .font(BJDesign.Typography.moodLabel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
            }

            // Statistically derived personality metrics
            if profile.dataPointCount >= 5 {
                Divider()
                    .padding(.vertical, 4)

                traitGaugeRow(
                    icon: "heart.circle.fill",
                    label: "Emotional Stability",
                    value: profile.emotionalStability,
                    color: .green,
                    description: profile.emotionalStability > 0.6
                        ? "You maintain steady emotional balance"
                        : "Your emotions show rich variety"
                )

                traitGaugeRow(
                    icon: "sun.max.fill",
                    label: "Optimism",
                    value: (profile.optimismBias + 1) / 2,  // normalize [-1,1] → [0,1]
                    color: .orange,
                    description: profile.optimismBias > 0.2
                        ? "Generally positive outlook"
                        : profile.optimismBias < -0.2
                            ? "Thoughtful, reflective tone"
                            : "Balanced perspective"
                )

                traitGaugeRow(
                    icon: "waveform.path",
                    label: "Reactivity",
                    value: min(1, profile.reactivityScore * 2),
                    color: .purple,
                    description: profile.reactivityScore > 0.3
                        ? "Emotionally responsive to events"
                        : "Even-keeled through changes"
                )

                if profile.recoveryRate > 0 {
                    traitGaugeRow(
                        icon: "arrow.up.heart.fill",
                        label: "Recovery",
                        value: min(1, profile.recoveryRate * 3),
                        color: .cyan,
                        description: profile.recoveryRate > 0.15
                            ? "Quick emotional bounce-back"
                            : "Takes time to process and recover"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BJDesign.Spacing.xl)
        .bjCard()
    }

    private func traitGaugeRow(
        icon: String,
        label: String,
        value: Double,
        color: Color,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Spacer()
            }
            ProgressView(value: max(0, min(1, value)))
                .tint(color)
            Text(description)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Flow Layout (for trait tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
