//
//  MoodScore.swift
//  better-journal
//
//  Calibrated, uncertainty-carrying mood result
//  produced by the late-fusion mood detection pipeline.
//

import Foundation

// MARK: - Per-Modality Contribution (stored for explainability)

struct ModalityContribution: Codable, Equatable, Sendable {
    let modality: ModalityType
    let valence: Double
    let arousal: Double
    let uncertainty: Double
    let calibratedConfidence: Double
    let influence: Double
    let keyFeatures: [String]
    /// This modality's emotion distribution (optional for backward compat)
    let emotionDistribution: EmotionDistribution

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modality = try c.decode(ModalityType.self, forKey: .modality)
        valence = try c.decode(Double.self, forKey: .valence)
        arousal = try c.decode(Double.self, forKey: .arousal)
        uncertainty = try c.decode(Double.self, forKey: .uncertainty)
        calibratedConfidence = try c.decode(Double.self, forKey: .calibratedConfidence)
        influence = try c.decode(Double.self, forKey: .influence)
        keyFeatures = try c.decode([String].self, forKey: .keyFeatures)
        emotionDistribution = (try? c.decode(EmotionDistribution.self, forKey: .emotionDistribution)) ?? .uniform
    }

    init(modality: ModalityType, valence: Double, arousal: Double,
         uncertainty: Double, calibratedConfidence: Double,
         influence: Double, keyFeatures: [String],
         emotionDistribution: EmotionDistribution = .uniform) {
        self.modality = modality; self.valence = valence; self.arousal = arousal
        self.uncertainty = uncertainty; self.calibratedConfidence = calibratedConfidence
        self.influence = influence; self.keyFeatures = keyFeatures
        self.emotionDistribution = emotionDistribution
    }
}

// MARK: - Emotion Candidate (for human-in-the-loop)

struct EmotionCandidate: Codable, Equatable, Sendable {
    let emotion: String
    let probability: Double
}

// MARK: - Calibrated Mood Score

struct MoodScore: Codable, Equatable, Sendable {

    // Emotion distribution
    var emotionDistribution: EmotionDistribution
    var topEmotions: [EmotionCandidate]
    var userConfirmedEmotion: String?

    // Dimensional values
    var valence: Double
    var arousal: Double

    // Uncertainty
    var valenceUncertainty: Double
    var arousalUncertainty: Double
    var overallConfidence: Double

    // Per-modality breakdown
    var contributions: [ModalityContribution]

    // Baseline-relative
    var baselineZScore: Double?
    var baselineLabel: String?

    // Categorical
    var primarySentiment: String

    // Metadata
    var timestamp: Date
    var hadConflict: Bool

    // MARK: - Convenience

    var bestEmotionLabel: String {
        userConfirmedEmotion ?? emotionDistribution.dominantEmotion.rawValue
    }

    var needsHumanConfirmation: Bool {
        userConfirmedEmotion == nil && overallConfidence < 0.5
    }

    // MARK: - Backward-Compatible Decoding

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        valence = try c.decode(Double.self, forKey: .valence)
        arousal = try c.decode(Double.self, forKey: .arousal)
        valenceUncertainty = try c.decode(Double.self, forKey: .valenceUncertainty)
        arousalUncertainty = try c.decode(Double.self, forKey: .arousalUncertainty)
        overallConfidence = try c.decode(Double.self, forKey: .overallConfidence)
        contributions = try c.decode([ModalityContribution].self, forKey: .contributions)
        baselineZScore = try c.decodeIfPresent(Double.self, forKey: .baselineZScore)
        baselineLabel = try c.decodeIfPresent(String.self, forKey: .baselineLabel)
        primarySentiment = try c.decode(String.self, forKey: .primarySentiment)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        hadConflict = try c.decode(Bool.self, forKey: .hadConflict)

        // New fields — decode with fallback defaults
        emotionDistribution = (try? c.decode(EmotionDistribution.self, forKey: .emotionDistribution)) ?? .uniform
        topEmotions = (try? c.decode([EmotionCandidate].self, forKey: .topEmotions))
            ?? [EmotionCandidate(emotion: primarySentiment, probability: 1.0)]
        userConfirmedEmotion = try? c.decodeIfPresent(String.self, forKey: .userConfirmedEmotion)
    }

    // MARK: - Direct Init

    init(emotionDistribution: EmotionDistribution, topEmotions: [EmotionCandidate],
         userConfirmedEmotion: String?, valence: Double, arousal: Double,
         valenceUncertainty: Double, arousalUncertainty: Double,
         overallConfidence: Double, contributions: [ModalityContribution],
         baselineZScore: Double?, baselineLabel: String?,
         primarySentiment: String, timestamp: Date, hadConflict: Bool) {
        self.emotionDistribution = emotionDistribution
        self.topEmotions = topEmotions
        self.userConfirmedEmotion = userConfirmedEmotion
        self.valence = valence; self.arousal = arousal
        self.valenceUncertainty = valenceUncertainty
        self.arousalUncertainty = arousalUncertainty
        self.overallConfidence = overallConfidence
        self.contributions = contributions
        self.baselineZScore = baselineZScore; self.baselineLabel = baselineLabel
        self.primarySentiment = primarySentiment
        self.timestamp = timestamp; self.hadConflict = hadConflict
    }

    static let neutral = MoodScore(
        emotionDistribution: .uniform,
        topEmotions: [EmotionCandidate(emotion: "neutral", probability: 1.0)],
        userConfirmedEmotion: nil,
        valence: 0.0, arousal: 0.35,
        valenceUncertainty: 0.5, arousalUncertainty: 0.2,
        overallConfidence: 0.0, contributions: [],
        baselineZScore: nil, baselineLabel: nil,
        primarySentiment: Sentiment.neutral.rawValue,
        timestamp: Date(), hadConflict: false
    )
}
