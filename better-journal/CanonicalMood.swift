//
//  CanonicalMood.swift
//  better-journal
//
//  Canonical mood normalization layer.
//
//  The internal 12-category `Sentiment` enum is preserved for analysis.
//  This system normalizes the VISUAL output to exactly 7 categories,
//  each backed by an SVG character asset in Assets.xcassets.
//
//  Architecture:
//    Sentiment (12) → MoodNormalizer → CanonicalMood (7) → MoodAssetProvider → Image
//
//  RULES:
//    • No view may display a mood character outside this system.
//    • No emojis. No dynamic blobs. No secondary characters.
//    • All mood characters go through CanonicalMoodView.
//

import SwiftUI

// MARK: - Canonical Mood Enum

/// The ONLY mood type allowed to reach UI character rendering.
/// Maps 1:1 with SVG assets in Assets.xcassets.
enum CanonicalMood: String, Codable, CaseIterable, Identifiable {
    case angry
    case calm
    case excited
    case sad
    case happy
    case anxious
    case neutral

    var id: String { rawValue }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .angry:   return "Angry"
        case .calm:    return "Calm"
        case .excited: return "Excited"
        case .sad:     return "Sad"
        case .happy:   return "Happy"
        case .anxious: return "Anxious"
        case .neutral: return "Neutral"
        }
    }

    /// Primary color for this canonical mood — used in gradients, pills, backgrounds.
    var color: Color {
        switch self {
        case .happy:   return Color(hex: "FFD700")   // Warm gold
        case .excited: return Color(hex: "FF8C42")   // Vibrant orange
        case .calm:    return Color(hex: "6BC5D2")   // Soft teal
        case .sad:     return Color(hex: "78909C")   // Slate blue
        case .angry:   return Color(hex: "E8614D")   // Deep coral
        case .anxious: return Color(hex: "FFAB40")   // Muted amber
        case .neutral: return Color(hex: "B0BEC5")   // Warm gray
        }
    }

    /// Soft gradient pair for cards and backgrounds.
    var gradient: [Color] {
        switch self {
        case .happy:   return [Color(hex: "FFD700"), Color(hex: "FFF3CD")]
        case .excited: return [Color(hex: "FF8C42"), Color(hex: "FFE0B2")]
        case .calm:    return [Color(hex: "6BC5D2"), Color(hex: "E8F4FD")]
        case .sad:     return [Color(hex: "78909C"), Color(hex: "CFD8DC")]
        case .angry:   return [Color(hex: "E8614D"), Color(hex: "FFE3E3")]
        case .anxious: return [Color(hex: "FFAB40"), Color(hex: "FFE0B2")]
        case .neutral: return [Color(hex: "B0BEC5"), Color(hex: "F5F5F5")]
        }
    }
}

// MARK: - Mood Normalizer

/// Single source of truth for mapping ANY mood signal → CanonicalMood.
/// Supports Sentiment enum, valence/arousal, and free-text labels.
struct MoodNormalizer {

    /// Primary entry point: normalize a `Sentiment` to `CanonicalMood`.
    static func canonicalMood(from sentiment: Sentiment?) -> CanonicalMood {
        guard let sentiment else { return .neutral }
        return sentimentMapping[sentiment] ?? .neutral
    }

    /// Normalize from valence + arousal numeric values.
    static func canonicalMood(
        valence: Double,
        arousal: Double,
        label: String? = nil
    ) -> CanonicalMood {
        // If we have a label, try keyword mapping first
        if let label = label?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           let match = keywordMapping[label] {
            return match
        }

        // Valence/Arousal quadrant mapping
        return quadrantMapping(valence: valence, arousal: arousal)
    }

    /// Normalize from a free-text label only.
    static func canonicalMood(fromLabel label: String) -> CanonicalMood {
        let key = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact keyword match
        if let match = keywordMapping[key] { return match }

        // Fuzzy: check if any keyword is contained in the label
        for (keyword, mood) in keywordMapping {
            if key.contains(keyword) { return mood }
        }

        return .neutral
    }

    // MARK: - Private Mapping Tables

    /// Direct Sentiment → CanonicalMood mapping.
    /// Stressed maps to .anxious per user requirement.
    private static let sentimentMapping: [Sentiment: CanonicalMood] = [
        .happy:      .happy,
        .grateful:   .happy,
        .calm:       .calm,
        .reflective: .calm,
        .excited:    .excited,
        .hopeful:    .excited,
        .sad:        .sad,
        .nostalgic:  .sad,
        .frustrated: .angry,
        .stressed:   .anxious,   // User: stressed → anxious, not angry
        .anxious:    .anxious,
        .neutral:    .neutral,
    ]

    /// Free-text keyword → CanonicalMood.
    /// Covers nuanced labels the mood engine might produce.
    private static let keywordMapping: [String: CanonicalMood] = [
        // Happy cluster
        "happy":        .happy,
        "content":      .happy,
        "grateful":     .happy,
        "thankful":     .happy,
        "proud":        .happy,
        "joyful":       .happy,
        "pleased":      .happy,
        "satisfied":    .happy,
        "cheerful":     .happy,
        "delighted":    .happy,
        "blissful":     .happy,
        "elated":       .happy,
        "warm":         .happy,

        // Excited cluster
        "excited":      .excited,
        "hopeful":      .excited,
        "optimistic":   .excited,
        "motivated":    .excited,
        "energetic":    .excited,
        "enthusiastic": .excited,
        "inspired":     .excited,
        "passionate":   .excited,
        "thrilled":     .excited,
        "eager":        .excited,
        "confident":    .excited,
        "pumped":       .excited,

        // Calm cluster
        "calm":         .calm,
        "peaceful":     .calm,
        "relaxed":      .calm,
        "serene":       .calm,
        "reflective":   .calm,
        "meditative":   .calm,
        "centered":     .calm,
        "grounded":     .calm,
        "mindful":      .calm,
        "tranquil":     .calm,
        "gentle":       .calm,
        "soothing":     .calm,

        // Sad cluster
        "sad":          .sad,
        "lonely":       .sad,
        "disappointed": .sad,
        "hopeless":     .sad,
        "nostalgic":    .sad,
        "melancholy":   .sad,
        "gloomy":       .sad,
        "sorrowful":    .sad,
        "heartbroken":  .sad,
        "grief":        .sad,
        "dejected":     .sad,
        "empty":        .sad,
        "wistful":      .sad,

        // Angry cluster
        "angry":        .angry,
        "frustrated":   .angry,
        "irritated":    .angry,
        "resentful":    .angry,
        "furious":      .angry,
        "enraged":      .angry,
        "bitter":       .angry,
        "hostile":      .angry,
        "outraged":     .angry,
        "annoyed":      .angry,
        "livid":        .angry,
        "agitated":     .angry,

        // Anxious cluster
        "anxious":      .anxious,
        "stressed":     .anxious,
        "overwhelmed":  .anxious,
        "restless":     .anxious,
        "tense":        .anxious,
        "nervous":      .anxious,
        "worried":      .anxious,
        "uneasy":       .anxious,
        "panicked":     .anxious,
        "fearful":      .anxious,
        "apprehensive": .anxious,
        "burned out":   .anxious,
        "insecure":     .anxious,
        "dread":        .anxious,

        // Neutral cluster
        "neutral":      .neutral,
        "balanced":     .neutral,
        "numb":         .neutral,
        "indifferent":  .neutral,
        "bored":        .neutral,
        "meh":          .neutral,
        "flat":         .neutral,
        "okay":         .neutral,
        "fine":         .neutral,
    ]

    /// Valence/Arousal quadrant → CanonicalMood.
    private static func quadrantMapping(valence: Double, arousal: Double) -> CanonicalMood {
        // Positive valence
        if valence > 0.2 {
            return arousal > 0.6 ? .excited : .happy
        }

        // Neutral valence
        if valence >= -0.2 {
            return arousal <= 0.4 ? .calm : .neutral
        }

        // Negative valence
        if arousal <= 0.4 {
            return .sad
        }

        // Negative + high arousal → angry vs anxious
        // >= 0.7 arousal = externalized anger, else internalized anxiety
        return arousal >= 0.7 ? .angry : .anxious
    }
}

// MARK: - Mood Asset Provider

/// Maps CanonicalMood → exact SVG asset name in Assets.xcassets.
/// This is the ONLY place asset names are referenced.
struct MoodAssetProvider {
    static func assetName(for mood: CanonicalMood) -> String {
        switch mood {
        case .angry:   return "AngryJ"
        case .calm:    return "CalmJ"
        case .excited: return "ExcitedJ"
        case .sad:     return "SadJ"
        case .happy:   return "HappyJ"
        case .anxious: return "AnxiousJ"
        case .neutral: return "NautralJ"   // Asset has this spelling
        }
    }
}

// MARK: - Canonical Mood View

/// The SINGLE reusable view for rendering mood characters.
/// All screens must use this — no direct Image() calls for mood assets.
struct CanonicalMoodView: View {
    let mood: CanonicalMood
    var size: CGFloat = 100

    /// Subtle idle animation
    @State private var isBreathing = false

    var body: some View {
        Image(MoodAssetProvider.assetName(for: mood))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(isBreathing ? 1.03 : 1.0)
            .animation(
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear { isBreathing = true }
            .accessibilityLabel("Mood: \(mood.displayName)")
    }
}

/// Convenience initializer from Sentiment (for analytics screens).
extension CanonicalMoodView {
    init(sentiment: Sentiment?, size: CGFloat = 100) {
        self.mood = MoodNormalizer.canonicalMood(from: sentiment)
        self.size = size
    }

    init(valence: Double, arousal: Double, size: CGFloat = 100) {
        self.mood = MoodNormalizer.canonicalMood(valence: valence, arousal: arousal)
        self.size = size
    }
}

// MARK: - JournalEntry Extension

extension JournalEntry {
    /// Canonical mood for analytics rendering.
    /// Individual note views should still use `resolvedEmotion` for full nuance.
    var canonicalMood: CanonicalMood {
        MoodNormalizer.canonicalMood(from: resolvedEmotion)
    }
}
