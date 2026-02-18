//
//  MoodGradientBackground.swift
//  better-journal
//

import SwiftUI

/// A mood-reactive gradient background that shifts subtly based on mood.
/// Uses warm amber tones for positive moods, cool slate for negative,
/// and neutral warm-gray for baseline.
struct MoodGradientBackground: View {
    let moodScore: MoodScore?
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: animateGradient ? .topLeading : .top,
            endPoint: animateGradient ? .bottomTrailing : .bottom
        )
        .animation(BJAnimation.breathe, value: animateGradient)
        .animation(BJAnimation.moodTransition, value: moodScore?.valence)
        .ignoresSafeArea()
        .onAppear { animateGradient = true }
    }

    private var gradientColors: [Color] {
        guard let score = moodScore else {
            return [BJDesign.MoodColor.warmGray, BJDesign.MoodColor.nearWhite]
        }

        let valence = score.valence
        let arousal = score.arousal

        if valence > 0.3 {
            // Positive mood
            if arousal > 0.6 {
                // Excited / energetic
                return [
                    BJDesign.MoodColor.sunsetGold.opacity(0.4),
                    BJDesign.MoodColor.warmGlow.opacity(0.3),
                    BJDesign.MoodColor.nearWhite
                ]
            } else {
                // Calm / grateful
                return [
                    BJDesign.MoodColor.softCream.opacity(0.5),
                    BJDesign.MoodColor.mist.opacity(0.3),
                    BJDesign.MoodColor.nearWhite
                ]
            }
        } else if valence < -0.3 {
            // Negative mood
            if arousal > 0.6 {
                // Frustrated / anxious
                return [
                    BJDesign.MoodColor.rose.opacity(0.3),
                    BJDesign.MoodColor.pewter.opacity(0.2),
                    BJDesign.MoodColor.nearWhite
                ]
            } else {
                // Sad / melancholic
                return [
                    BJDesign.MoodColor.stormGray.opacity(0.2),
                    BJDesign.MoodColor.mist.opacity(0.2),
                    BJDesign.MoodColor.nearWhite
                ]
            }
        } else {
            // Neutral
            return [
                BJDesign.MoodColor.warmGray.opacity(0.5),
                BJDesign.MoodColor.nearWhite
            ]
        }
    }
}

// MARK: - Mood Indicator Bar

/// A thin vertical bar that indicates mood via color, used in entry rows.
struct MoodIndicatorBar: View {
    let sentiment: Sentiment?

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 4)
    }

    private var barColor: some ShapeStyle {
        guard let sentiment else {
            return AnyShapeStyle(Color(.systemGray4))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [sentiment.color, sentiment.color.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
