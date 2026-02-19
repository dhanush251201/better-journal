//
//  RecapCardStack.swift
//  better-journal
//
//  Full-screen swipeable "Memories" card stack for weekly digests.
//  Soft depth transitions, gentle parallax, celebration animations.
//  Emotion-first language — no text overload.
//

import SwiftUI

struct RecapCardStack: View {
    let cards: [RecapCard]
    @State private var currentIndex = 0
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Animated background gradient based on current card
            backgroundGradient
                .ignoresSafeArea()
                .animation(InsightAnimation.slow, value: currentIndex)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        BJHaptic.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(BJDesign.Spacing.xl)
                }

                Spacer()

                // Card pager
                TabView(selection: $currentIndex) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        recapCardView(card, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: UIScreen.main.bounds.height * 0.55)
                .onChange(of: currentIndex) { _, _ in
                    BJHaptic.selection()
                }

                Spacer()

                // Page indicator text
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(InsightAnimation.cardEntrance) { appeared = true }
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private func recapCardView(_ card: RecapCard, index: Int) -> some View {
        let isActive = index == currentIndex

        VStack(spacing: BJDesign.Spacing.xl) {
            cardIcon(card)
                .font(.system(size: 44))
                .scaleEffect(isActive ? 1.0 : 0.8)
                .animation(InsightAnimation.gentle, value: isActive)

            cardText(card)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(6)
                .padding(.horizontal, BJDesign.Spacing.xl)

            cardSubtext(card)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(InsightDesign.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: InsightDesign.largeCardRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .shadow(color: .black.opacity(0.1), radius: 30, y: 10)
        )
        .padding(.horizontal, BJDesign.Spacing.xl)
        .scaleEffect(isActive ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(
            InsightAnimation.cardEntrance.delay(Double(index) * 0.1),
            value: appeared
        )
    }

    // MARK: - Card Content

    private func cardIcon(_ card: RecapCard) -> some View {
        Group {
            switch card {
            case .energySummary(_, let mood):
                Image(systemName: Sentiment(rawValue: mood)?.iconName ?? "sparkles")
                    .foregroundStyle(InsightPalette.color(for: mood))
            case .steadiestDay:
                Image(systemName: "leaf.fill")
                    .foregroundStyle(InsightPalette.calmSky)
            case .highlightEntry:
                Image(systemName: "star.fill")
                    .foregroundStyle(InsightPalette.joyGold)
            case .weekComparison(_, let shift):
                Image(systemName: shift > 0 ? "arrow.up.heart.fill" : "arrow.down.heart.fill")
                    .foregroundStyle(shift > 0 ? InsightPalette.joyGold : InsightPalette.slateBlue)
            case .milestone(_, let type):
                milestoneIcon(type)
            }
        }
    }

    private func milestoneIcon(_ type: RecapCard.MilestoneType) -> some View {
        Group {
            switch type {
            case .streak30:
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            case .entries100:
                Image(systemName: "book.fill")
                    .foregroundStyle(InsightPalette.lavender)
            case .stabilityImproved:
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func cardText(_ card: RecapCard) -> Text {
        switch card {
        case .energySummary(let text, _),
             .steadiestDay(let text, _),
             .highlightEntry(let text, _, _),
             .weekComparison(let text, _),
             .milestone(let text, _):
            return Text(text)
        }
    }

    @ViewBuilder
    private func cardSubtext(_ card: RecapCard) -> some View {
        switch card {
        case .milestone:
            Text("A meaningful milestone ✨")
        case .weekComparison(_, let shift):
            Text(shift > 0 ? "Things are looking up." : "Every season has its purpose.")
        default:
            EmptyView()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let mood: String
        if currentIndex < cards.count {
            switch cards[currentIndex] {
            case .energySummary(_, let m): mood = m
            case .steadiestDay: mood = "calm"
            case .highlightEntry: mood = "happy"
            case .weekComparison(_, let shift): mood = shift > 0 ? "happy" : "reflective"
            case .milestone: mood = "grateful"
            }
        } else {
            mood = "neutral"
        }

        let colors = InsightPalette.gradient(for: mood)
        return LinearGradient(
            colors: [colors[0].opacity(0.8), colors[1].opacity(0.4), Color.black.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Confetti Particle Effect (for milestones)

struct ConfettiView: View {
    @State private var particles: [(id: UUID, x: CGFloat, y: CGFloat, color: Color, rotation: Double)] = []
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 6, height: 6)
                    .offset(x: animate ? particle.x : 0, y: animate ? particle.y : -50)
                    .rotationEffect(.degrees(animate ? particle.rotation : 0))
                    .opacity(animate ? 0 : 1)
            }
        }
        .onAppear {
            particles = (0..<30).map { _ in
                (
                    id: UUID(),
                    x: CGFloat.random(in: -150...150),
                    y: CGFloat.random(in: 100...400),
                    color: [InsightPalette.joyGold, InsightPalette.calmSky,
                            InsightPalette.lavender, InsightPalette.coralDeep].randomElement()!,
                    rotation: Double.random(in: 0...360)
                )
            }
            withAnimation(.easeOut(duration: 2.0)) {
                animate = true
            }
            BJHaptic.celebrate()
        }
    }
}
