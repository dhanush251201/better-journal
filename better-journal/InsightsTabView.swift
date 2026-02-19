//
//  InsightsTabView.swift
//  better-journal
//
//  Premium insights landing page.
//  Calm · Airy · Reflective · Soft · Premium · Almost therapeutic.
//
//  Layout hierarchy:
//    Greeting + emotional summary
//    → Weekly sparkline (gentle insight)
//    → Mood distribution ring (this month)
//    → Natural language insight cards
//    → "Week in Review" → RecapCardStack
//    → "Year Overview" → MoodHeatmapView
//

import SwiftData
import SwiftUI

struct InsightsTabView: View {
    let modelContainer: ModelContainer
    let store: JournalStore

    @State private var sparklineData: [SparklinePoint] = []
    @State private var distribution: [MoodAnalyticsStore.MoodDistributionItem] = []
    @State private var insights: [NaturalInsight] = []
    @State private var recapCards: [RecapCard] = []
    @State private var heatmapDays: [HeatmapDay] = []
    @State private var streaks: StreakInfo?
    @State private var isLoading = true
    @State private var appeared = false

    @State private var showRecap = false
    @State private var showHeatmap = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: InsightDesign.sectionSpacing) {
                // MARK: - Greeting
                greetingSection
                    .padding(.top, BJDesign.Spacing.xl)

                // MARK: - Weekly Sparkline
                if !sparklineData.isEmpty {
                    WeeklySparklineChart(data: sparklineData)
                        .padding(.horizontal, BJDesign.Spacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(InsightAnimation.cardEntrance.delay(0.1), value: appeared)
                }

                // MARK: - Mood Character
                if !distribution.isEmpty {
                    VStack(spacing: 12) {
                        // Derive canonical mood from top distribution category
                        let topSentiment = distribution.first.flatMap { Sentiment(rawValue: $0.category) }
                        let canonical = MoodNormalizer.canonicalMood(from: topSentiment)

                        CanonicalMoodView(mood: canonical, size: 140)

                        // Show canonical mood label
                        Text("Mostly \(canonical.displayName)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(BJDesign.Palette.grayBlue)
                    }
                    .padding(BJDesign.Spacing.xl)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                            .fill(BJDesign.Palette.cream.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                    )
                    .padding(.horizontal, BJDesign.Spacing.lg)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(InsightAnimation.cardEntrance.delay(0.2), value: appeared)
                }

                // MARK: - Natural Language Insights
                if !insights.isEmpty {
                    insightCardsSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(InsightAnimation.cardEntrance.delay(0.3), value: appeared)
                }

                // MARK: - Streak Banner
                if let streaks, streaks.journalingStreak > 0 {
                    streakBanner(streaks)
                        .padding(.horizontal, BJDesign.Spacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(InsightAnimation.cardEntrance.delay(0.35), value: appeared)
                }

                // MARK: - Action Cards
                actionCardsSection
                    .padding(.horizontal, BJDesign.Spacing.lg)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(InsightAnimation.cardEntrance.delay(0.4), value: appeared)

                Spacer(minLength: 60)
            }
        }
        .background(MoodGradientBackground(moodScore: nil))
        .onAppear { loadInsights() }
        .fullScreenCover(isPresented: $showRecap) {
            RecapCardStack(cards: recapCards)
        }
        .sheet(isPresented: $showHeatmap) {
            NavigationStack {
                ScrollView {
                    MoodHeatmapView(days: heatmapDays)
                        .padding(.vertical, BJDesign.Spacing.xl)
                }
                .background(MoodGradientBackground(moodScore: nil))
                .navigationTitle("Year in Review")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showHeatmap = false }
                    }
                }
            }
        }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(spacing: BJDesign.Spacing.sm) {
            Text(greetingText)
                .font(BJDesign.Typography.largeTitle)
                .opacity(appeared ? 1 : 0)
                .animation(InsightAnimation.gentle, value: appeared)

            if let dominantMood = distribution.first?.category,
               let sentiment = Sentiment(rawValue: dominantMood) {
                HStack(spacing: 6) {
                    Image(systemName: sentiment.iconName)
                        .foregroundStyle(InsightPalette.color(for: dominantMood))
                    Text("Mostly \(sentiment.displayName.lowercased()) this month")
                        .font(BJDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                .animation(InsightAnimation.gentle.delay(0.1), value: appeared)
            } else {
                Text("Your emotional landscape")
                    .font(BJDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, BJDesign.Spacing.xl)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        if hour < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    // MARK: - Insight Cards

    private var insightCardsSection: some View {
        VStack(spacing: BJDesign.Spacing.md) {
            ForEach(Array(insights.prefix(4).enumerated()), id: \.element.id) { index, insight in
                insightCard(insight, delay: Double(index) * InsightAnimation.staggerDelay)
            }
        }
        .padding(.horizontal, BJDesign.Spacing.lg)
    }

    private func insightCard(_ insight: NaturalInsight, delay: Double) -> some View {
        HStack(spacing: BJDesign.Spacing.md) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(iconColor(for: insight.category))
                .frame(width: 36)

            Text(insight.text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)

            Spacer()
        }
        .padding(InsightDesign.cardPadding)
        .bjGlassCard()
    }

    private func iconColor(for category: NaturalInsight.InsightCategory) -> Color {
        switch category {
        case .timeOfDay:   return InsightPalette.joyGold
        case .dayOfWeek:   return InsightPalette.calmSky
        case .streak:      return .orange
        case .volatility:  return InsightPalette.lavender
        case .seasonal:    return .green
        case .milestone:   return InsightPalette.coralDeep
        }
    }

    // MARK: - Streak Banner

    private func streakBanner(_ streaks: StreakInfo) -> some View {
        HStack(spacing: BJDesign.Spacing.lg) {
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("\(streaks.journalingStreak)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("day streak")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            if streaks.positiveStreak > 0 {
                Divider().frame(height: 40)
                VStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundStyle(InsightPalette.joyGold)
                    Text("\(streaks.positiveStreak)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("positive days")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if streaks.calmStreak > 0 {
                Divider().frame(height: 40)
                VStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(InsightPalette.calmSky)
                    Text("\(streaks.calmStreak)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("calm days")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(InsightDesign.cardPadding)
        .bjGlassCard()
    }

    // MARK: - Action Cards

    private var actionCardsSection: some View {
        VStack(spacing: BJDesign.Spacing.md) {
            // Week in Review
            if !recapCards.isEmpty {
                Button {
                    BJHaptic.soft()
                    showRecap = true
                } label: {
                    actionCard(
                        icon: "sparkles.rectangle.stack.fill",
                        title: "Week in Review",
                        subtitle: "See your emotional story",
                        color: InsightPalette.lavender
                    )
                }
                .buttonStyle(.plain)
            }

            // Year Overview
            Button {
                BJHaptic.soft()
                Task { await loadHeatmap() }
                showHeatmap = true
            } label: {
                actionCard(
                    icon: "calendar.badge.clock",
                    title: "Year in Review",
                    subtitle: "365 days of emotional data",
                    color: InsightPalette.calmSky
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: BJDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BJDesign.Typography.headline)
                Text(subtitle)
                    .font(BJDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(InsightDesign.cardPadding)
        .bjGlassCard()
    }

    // MARK: - Data Loading

    private func loadInsights() {
        guard isLoading else { return }
        let container = modelContainer

        Task {
            let engine = InsightEngine(modelContainer: container)

            async let sparkline = engine.fetchSparklineData(days: 7)
            async let dist = engine.fetchMoodDistribution(days: 30)
            async let naturalInsights = engine.generateNaturalInsights(days: 30)
            async let recap = engine.generateRecapCards()
            async let streakData = engine.computeStreaks()

            let s = await sparkline
            let d = await dist
            let n = await naturalInsights
            let r = await recap
            let st = await streakData

            await MainActor.run {
                sparklineData = s
                distribution = d
                insights = n
                recapCards = r
                streaks = st
                isLoading = false
                withAnimation(InsightAnimation.cardEntrance) { appeared = true }
            }
        }
    }

    private func loadHeatmap() async {
        guard heatmapDays.isEmpty else { return }
        let engine = InsightEngine(modelContainer: modelContainer)
        let days = await engine.fetchHeatmapData()
        await MainActor.run { heatmapDays = days }
    }
}
