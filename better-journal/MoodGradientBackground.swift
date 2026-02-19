//
//  MoodGradientBackground.swift
//  better-journal
//
//  Mood-reactive gradient background driven by the resolved emotion.
//  Maps all 12 Sentiment cases to curated gradient palettes.
//

import SwiftUI

/// A mood-reactive gradient background that shifts based on the dominant emotion.
/// Accepts multiple init paths — all converge to the same emotion-based palette.
struct MoodGradientBackground: View {
    private let emotion: Sentiment?
    private let arousal: Double
    @State private var animateGradient = false

    /// Init from a resolved emotion (preferred path — single source of truth).
    init(emotion: Sentiment?, arousal: Double = 0.35) {
        self.emotion = emotion
        self.arousal = arousal
    }

    /// Init from a saved MoodScore — derives emotion from distribution.
    init(moodScore: MoodScore?) {
        if let score = moodScore,
           let s = Sentiment(rawValue: score.bestEmotionLabel) {
            self.emotion = s
        } else {
            self.emotion = nil
        }
        self.arousal = moodScore?.arousal ?? 0.35
    }

    /// Init from raw valence/arousal (live editor preview).
    init(valence: Double, arousal: Double) {
        self.emotion = Sentiment.fromValenceArousal(valence: valence, arousal: arousal)
        self.arousal = arousal
    }

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: animateGradient ? .topLeading : .top,
            endPoint: animateGradient ? .bottomTrailing : .bottom
        )
        .animation(BJAnimation.breathe, value: animateGradient)
        .animation(BJAnimation.moodTransition, value: emotion)
        .ignoresSafeArea()
        .onAppear { animateGradient = true }
    }

    // MARK: - Emotion → Gradient Palette (vivid, clearly distinct)

    private var gradientColors: [Color] {
        guard let emotion else {
            return [BJDesign.MoodColor.warmGray, BJDesign.MoodColor.nearWhite]
        }

        let isHighArousal = arousal > 0.6

        switch emotion {
        case .happy:
            return [
                BJDesign.MoodColor.sunsetGold.opacity(isHighArousal ? 0.55 : 0.4),
                BJDesign.MoodColor.warmGlow.opacity(0.35),
                BJDesign.MoodColor.nearWhite
            ]
        case .excited:
            return [
                Color.orange.opacity(0.5),
                BJDesign.MoodColor.sunsetGold.opacity(0.3),
                BJDesign.MoodColor.nearWhite
            ]
        case .grateful:
            return [
                Color.pink.opacity(0.4),
                BJDesign.MoodColor.softCream.opacity(0.35),
                BJDesign.MoodColor.nearWhite
            ]
        case .calm:
            return [
                Color.mint.opacity(0.4),
                BJDesign.MoodColor.mist.opacity(0.3),
                BJDesign.MoodColor.nearWhite
            ]
        case .hopeful:
            return [
                Color.cyan.opacity(0.4),
                BJDesign.MoodColor.softCream.opacity(0.3),
                BJDesign.MoodColor.nearWhite
            ]
        case .reflective:
            return [
                Color.indigo.opacity(0.35),
                BJDesign.MoodColor.mist.opacity(0.25),
                BJDesign.MoodColor.nearWhite
            ]
        case .nostalgic:
            return [
                Color.brown.opacity(0.35),
                BJDesign.MoodColor.softCream.opacity(0.3),
                BJDesign.MoodColor.nearWhite
            ]
        case .anxious:
            return [
                Color.yellow.opacity(0.45),
                Color.orange.opacity(0.2),
                BJDesign.MoodColor.nearWhite
            ]
        case .sad:
            return [
                Color.blue.opacity(0.4),
                BJDesign.MoodColor.stormGray.opacity(0.3),
                BJDesign.MoodColor.nearWhite
            ]
        case .frustrated:
            return [
                BJDesign.MoodColor.rose.opacity(0.45),
                Color.red.opacity(0.2),
                BJDesign.MoodColor.nearWhite
            ]
        case .stressed:
            return [
                Color.red.opacity(0.4),
                BJDesign.MoodColor.stormGray.opacity(0.25),
                BJDesign.MoodColor.nearWhite
            ]
        case .neutral:
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
