//
//  ContentView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import SwiftData
import SwiftUI

// MARK: - Motivational Messages

private let motivationalMessages: [String] = [
    "Every day is a fresh page in your story.",
    "Small steps forward are still progress.",
    "Your thoughts matter — write them down.",
    "Reflection is the beginning of growth.",
    "Be kind to yourself today.",
    "What you feel is valid and worth exploring.",
    "Progress, not perfection.",
    "Today is full of possibilities.",
    "You are stronger than you think.",
    "Take a moment to appreciate how far you've come.",
    "Your journal is a safe space — let it all out.",
    "Gratitude turns what we have into enough.",
    "One mindful moment can change your whole day.",
    "Writing is thinking on paper.",
    "You don't have to have it all figured out.",
    "The best time to start is now.",
    "Every entry is a gift to your future self.",
]

// MARK: - Content View

struct ContentView: View {
    @State private var store: JournalStore
    @State private var showingNewEntry = false
    @State private var showingInsights = false
    @State private var appeared = false
    private let modelContainer: ModelContainer?

    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
        _store = State(initialValue: JournalStore(modelContainer: modelContainer))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Warm cream base
                BJDesign.Palette.cream.ignoresSafeArea()

                // Mood gradient background — reads from resolvedEmotion
                MoodGradientBackground(emotion: store.entries.first?.resolvedEmotion)

                VStack(spacing: 0) {
                    carouselView
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if store.entries.isEmpty {
                        emptyState
                            .frame(maxHeight: .infinity)
                    } else {
                        entryList
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingInsights = true
                        BJHaptic.soft()
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(BJDesign.Palette.warmOrange)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                        BJHaptic.soft()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                EntryEditorView(store: store)
            }
            .sheet(isPresented: $showingInsights) {
                NavigationStack {
                    if let container = modelContainer {
                        InsightsTabView(modelContainer: container, store: store)
                            .navigationTitle("Insights")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showingInsights = false }
                                }
                            }
                    } else {
                        WeeklyInsightView(
                            summaries: store.moodSummaries,
                            insight: store.journalInsight,
                            profile: store.personalityProfile
                        )
                        .navigationTitle("Insights")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingInsights = false }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Computed

    private var dailyMessage: String {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return motivationalMessages[dayIndex % motivationalMessages.count]
    }

    // MARK: - Carousel

    private var carouselView: some View {
        let current = store.currentStreak
        let longest = store.longestStreak

        return TabView {
            // Slide 1: Daily motivational message
            VStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(BJDesign.Palette.warmOrange)
                Text(dailyMessage)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(BJDesign.Palette.grayBlue)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                    .fill(BJDesign.Palette.cream.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .padding(.horizontal, 16)

            // Slide 2: AI Insight
            if let insight = store.journalInsight {
                VStack(spacing: 10) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.title2)
                        .foregroundStyle(BJDesign.Palette.softLavender)
                    Text(insight)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(BJDesign.Palette.grayBlue)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                        .fill(BJDesign.Palette.cream.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                )
                .padding(.horizontal, 16)
            }

            // Slide 3: Mood Character (if enough data)
            if !store.moodSummaries.isEmpty {
                VStack(spacing: 4) {
                    CanonicalMoodView(
                        sentiment: store.entries.first?.resolvedEmotion,
                        size: 80
                    )
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                        .fill(BJDesign.Palette.cream.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                )
                .padding(.horizontal, 16)
            }

            // Slide 4: Streak insights
            HStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(BJDesign.Palette.warmOrange)
                    Text(verbatim: "\(current)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(BJDesign.Palette.grayBlue)
                    Text("Current Streak")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                VStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(Color(hex: "FFD700"))
                    Text(verbatim: "\(longest)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(BJDesign.Palette.grayBlue)
                    Text("Longest Streak")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                    .fill(BJDesign.Palette.cream.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: BJDesign.Radius.large, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .padding(.horizontal, 16)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 160)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            // Show the character in a neutral state
            CanonicalMoodView(mood: .calm, size: 120)
                .scaleEffect(appeared ? 1.0 : 0.8)
                .animation(BJAnimation.springGentle, value: appeared)

            Text("No Entries Yet")
                .font(BJDesign.Typography.title)
                .foregroundStyle(BJDesign.Palette.grayBlue)

            Text("Tap the pencil icon to write your first entry.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .opacity(appeared ? 1.0 : 0)
        .animation(BJAnimation.moodTransition, value: appeared)
    }

    // MARK: - Entry List

    private var entryList: some View {
        List {
            ForEach(store.entries) { entry in
                NavigationLink(destination: EntryEditorView(store: store, entry: entry)) {
                    EntryRowView(entry: entry, store: store)
                }
            }
            .onDelete(perform: store.delete)
            .listRowBackground(
                RoundedRectangle(cornerRadius: BJDesign.Radius.medium, style: .continuous)
                    .fill(BJDesign.Palette.cream.opacity(0.6))
                    .padding(.vertical, 2)
            )
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Entry Row

struct EntryRowView: View {
    let entry: JournalEntry
    let store: JournalStore
    @State private var appeared = false

    private var formattedDate: String {
        entry.date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Mood indicator bar — single source of truth
            MoodIndicatorBar(sentiment: entry.resolvedEmotion)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 8) {
                // Photo collage thumbnail
                if let collage = entry.collage, !collage.isEmpty {
                    CollageDisplayView(collageData: collage, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: BJDesign.Radius.small))
                }

                // Drawing thumbnail
                if let drawingID = entry.drawingID {
                    DrawingThumbnailView(drawingID: drawingID, height: 70)
                }

                // Title + date
                HStack {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Content preview
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Mood badges — all from resolvedEmotion
                HStack(spacing: 8) {
                    if let emotion = entry.resolvedEmotion {
                        SentimentTagView(sentiment: emotion) {
                            // On tap → allow user to change mood
                            store.confirmUserEmotion(for: entry.id, emotion: emotion)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    if let score = entry.moodScore {
                        // Baseline-relative label
                        if let label = score.baselineLabel {
                            HStack(spacing: 3) {
                                Image(systemName: baselineIcon(for: score.baselineZScore))
                                    .font(.caption2)
                                Text(label)
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .foregroundStyle(baselineColor(for: score.baselineZScore).opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(baselineColor(for: score.baselineZScore).opacity(0.1), in: Capsule())
                        }

                        // Confidence indicator
                        if score.overallConfidence > 0.3 {
                            HStack(spacing: 2) {
                                Image(systemName: confidenceIcon(score.overallConfidence))
                                    .font(.caption2)
                                Text(confidenceLabel(score.overallConfidence))
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .foregroundStyle(BJDesign.Palette.softLavender.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(BJDesign.Palette.softLavender.opacity(0.1), in: Capsule())
                        }

                        // Conflict warning
                        if score.hadConflict {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(BJDesign.Palette.warmOrange.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.leading, BJDesign.Spacing.md)
        }
        .padding(.vertical, 4)
        .background(moodHaloBackground)
        .opacity(appeared ? 1.0 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(BJAnimation.springEntry) {
                appeared = true
            }
        }
    }

    // MARK: - Mood Halo Background

    /// Soft radial glow behind the note, colored by the resolved emotion.
    @ViewBuilder
    private var moodHaloBackground: some View {
        let confidence = entry.moodScore?.overallConfidence ?? 0.3

        if let emotion = entry.resolvedEmotion {
            let haloColor = emotion.color
            let intensity = min(0.25, confidence * 0.3)

            RadialGradient(
                gradient: Gradient(colors: [
                    haloColor.opacity(intensity),
                    haloColor.opacity(intensity * 0.4),
                    Color.clear
                ]),
                center: .leading,
                startRadius: 0,
                endRadius: 200
            )
            .animation(BJAnimation.moodTransition, value: emotion)
        }
    }

    // MARK: - Helpers

    private func baselineIcon(for zScore: Double?) -> String {
        guard let z = zScore else { return "ellipsis.circle" }
        if z > 0.5 { return "arrow.up.circle.fill" }
        if z < -0.5 { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private func baselineColor(for zScore: Double?) -> Color {
        guard let z = zScore else { return .gray }
        if z > 0.5 { return .green }
        if z < -0.5 { return .orange }
        return .blue
    }

    private func confidenceIcon(_ confidence: Double) -> String {
        if confidence > 0.7 { return "checkmark.seal.fill" }
        if confidence > 0.4 { return "circle.dotted.circle" }
        return "questionmark.circle"
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        if confidence > 0.7 { return "High confidence" }
        if confidence > 0.4 { return "Moderate" }
        return "Tentative"
    }
}

#Preview {
    ContentView()
}
