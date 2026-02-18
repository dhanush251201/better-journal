//
//  PersonalityProfile.swift
//  better-journal
//
//  Long-term personality model derived entirely on-device
//  from mood history. Stored locally and never exported.
//

import Foundation

// MARK: - Supporting Types

/// Mood correlation for a specific hour-of-day bucket.
struct TimePattern: Codable, Equatable, Sendable {
    var hourBucket: Int        // 0 – 23
    var averageValence: Double
    var averageArousal: Double
    var sampleCount: Int
}

/// Mood correlation for a calendar month.
struct SeasonalTrend: Codable, Equatable, Sendable {
    var month: Int             // 1 – 12
    var averageValence: Double
    var averageArousal: Double
    var sampleCount: Int
}

// MARK: - PersonalityProfile

struct PersonalityProfile: Codable, Equatable, Sendable {

    // --- Emotional Baseline ---
    var baselineValence: Double
    var baselineArousal: Double

    // --- Volatility (std deviation of valence over time) ---
    var volatilityIndex: Double

    // --- New: Statistically derived personality traits ---

    /// 1 - σ_valence. High = emotionally stable. [0, 1]
    var emotionalStability: Double

    /// Mean valence. Positive = optimistic bias.
    var optimismBias: Double

    /// Fraction of entries below -0.3 valence. [0, 1]
    var negativeAffectBias: Double

    /// Mean |Δv| between consecutive entries. High = reactive.
    var reactivityScore: Double

    /// Mean slope of valence recovery after sub-baseline dips.
    var recoveryRate: Double

    // --- Longitudinal ---

    /// Top recurring sentiments (e.g. ["calm", "reflective"])
    var dominantTraits: [String]

    /// Hour-of-day mood patterns
    var timePatterns: [TimePattern]

    /// Month-of-year mood trends
    var seasonalTrends: [SeasonalTrend]

    /// NLP-extracted recurring themes from text
    var recurringThemes: [String]

    // --- Bookkeeping ---
    var lastUpdated: Date
    var dataPointCount: Int

    // MARK: - Factory

    static let empty = PersonalityProfile(
        baselineValence: 0,
        baselineArousal: 0.3,
        volatilityIndex: 0,
        emotionalStability: 0.5,
        optimismBias: 0,
        negativeAffectBias: 0,
        reactivityScore: 0,
        recoveryRate: 0,
        dominantTraits: [],
        timePatterns: [],
        seasonalTrends: [],
        recurringThemes: [],
        lastUpdated: Date(),
        dataPointCount: 0
    )
}
