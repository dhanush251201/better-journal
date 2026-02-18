//
//  MoodScore.swift
//  better-journal
//
//  Calibrated, uncertainty-carrying mood result
//  produced by the 6-layer mood detection pipeline.
//

import Foundation

// MARK: - Per-Modality Contribution (stored for explainability)

struct ModalityContribution: Codable, Equatable, Sendable {
    let modality: ModalityType
    let valence: Double
    let arousal: Double
    let uncertainty: Double
    let calibratedConfidence: Double
    /// Fraction of total precision this modality contributed to the fused result.
    let influence: Double
    /// Top human-readable feature labels (e.g. "uplifting language", "warm colors").
    let keyFeatures: [String]
}

// MARK: - Calibrated Mood Score

/// Per-entry fused mood result using the Valence-Arousal model with
/// full uncertainty propagation, per-modality contributions, temporal
/// smoothing state, and baseline-relative z-scores.
struct MoodScore: Codable, Equatable, Sendable {

    // MARK: - Fused Dimensional Values

    /// Fused valence after Bayesian fusion + Kalman smoothing. [-1, 1]
    var valence: Double

    /// Fused arousal after Bayesian fusion + Kalman smoothing. [0, 1]
    var arousal: Double

    // MARK: - Uncertainty

    /// Fused standard deviation (σ) of the valence estimate.
    var valenceUncertainty: Double

    /// Fused standard deviation (σ) of the arousal estimate.
    var arousalUncertainty: Double

    /// Overall calibrated confidence. [0, 1]
    /// This is NOT a naive sum — it's derived from fused precision
    /// and penalized by inter-modality conflict.
    var overallConfidence: Double

    // MARK: - Per-Modality Breakdown

    /// Contributions from each modality that participated.
    var contributions: [ModalityContribution]

    // MARK: - Baseline-Relative

    /// Z-score of valence relative to user's personal baseline.
    /// `nil` if baseline is not yet active (< 10 entries).
    var baselineZScore: Double?

    /// Human-readable baseline-relative label.
    var baselineLabel: String?

    // MARK: - Categorical (presentation layer only)

    /// Nearest categorical sentiment, mapped from continuous VA space.
    var primarySentiment: String

    // MARK: - Metadata

    var timestamp: Date

    /// Whether modalities significantly disagreed during fusion.
    var hadConflict: Bool

    // MARK: - Factory

    static let neutral = MoodScore(
        valence: 0.0,
        arousal: 0.35,
        valenceUncertainty: 0.5,
        arousalUncertainty: 0.2,
        overallConfidence: 0.0,
        contributions: [],
        baselineZScore: nil,
        baselineLabel: nil,
        primarySentiment: Sentiment.neutral.rawValue,
        timestamp: Date(),
        hadConflict: false
    )
}
