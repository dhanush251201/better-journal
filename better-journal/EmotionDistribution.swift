//
//  EmotionDistribution.swift
//  better-journal
//
//  Probability distribution over 12 emotion categories.
//  Every modality analyzer outputs one of these; the fusion
//  engine merges them via confidence-weighted averaging.
//

import Foundation

// MARK: - Emotion Distribution

/// A probability distribution over the 12 `Sentiment` emotion categories.
///
/// Each value in `probabilities` is in [0, 1] and they sum to ~1.0.
/// This is the universal output format for all modality analyzers.
struct EmotionDistribution: Codable, Equatable, Sendable {

    /// Ordered probabilities matching Sentiment.allCases order:
    /// happy, grateful, calm, excited, hopeful, reflective,
    /// nostalgic, anxious, sad, frustrated, stressed, neutral
    var probabilities: [Double]

    /// How many modalities contributed to this distribution
    var sourceCount: Int

    // MARK: - Init

    init(probabilities: [Double] = Array(repeating: 0, count: 12), sourceCount: Int = 1) {
        // Ensure exactly 12 bins
        var p = probabilities
        while p.count < 12 { p.append(0) }
        if p.count > 12 { p = Array(p.prefix(12)) }
        self.probabilities = p
        self.sourceCount = sourceCount
    }

    /// Uniform distribution (maximum uncertainty)
    static let uniform = EmotionDistribution(
        probabilities: Array(repeating: 1.0 / 12.0, count: 12)
    )

    // MARK: - Queries

    /// All Sentiment cases in order (matches probabilities array index)
    static let emotions: [Sentiment] = Sentiment.allCases

    /// The dominant (highest probability) emotion
    var dominantEmotion: Sentiment {
        let maxIdx = probabilities.enumerated().max(by: { $0.element < $1.element })?.offset ?? 11
        return Self.emotions[maxIdx]
    }

    /// Probability of the dominant emotion
    var dominantProbability: Double {
        probabilities.max() ?? 0
    }

    /// Top-K emotion candidates with their probabilities, sorted descending
    func topK(_ k: Int = 3) -> [(emotion: Sentiment, probability: Double)] {
        zip(Self.emotions, probabilities)
            .sorted { $0.1 > $1.1 }
            .prefix(k)
            .map { (emotion: $0.0, probability: $0.1) }
    }

    /// Confidence: how peaked the distribution is.
    /// 1.0 = all probability on one emotion. 0.0 = perfectly uniform.
    /// Uses normalized negative entropy.
    var confidence: Double {
        let maxEntropy = log(12.0)  // uniform distribution entropy
        var entropy = 0.0
        for p in probabilities where p > 0.001 {
            entropy -= p * log(p)
        }
        return max(0, 1.0 - entropy / maxEntropy)
    }

    /// Derived valence from distribution (weighted average of emotion valences)
    var valence: Double {
        zip(Self.emotions, probabilities).reduce(0.0) { sum, pair in
            sum + pair.0.valenceArousal.0 * pair.1
        }
    }

    /// Derived arousal from distribution (weighted average of emotion arousals)
    var arousal: Double {
        zip(Self.emotions, probabilities).reduce(0.0) { sum, pair in
            sum + pair.0.valenceArousal.1 * pair.1
        }
    }

    // MARK: - Operations

    /// Normalize so probabilities sum to 1.0
    mutating func normalize() {
        let total = probabilities.reduce(0, +)
        guard total > 0 else {
            probabilities = Array(repeating: 1.0 / 12.0, count: 12)
            return
        }
        probabilities = probabilities.map { $0 / total }
    }

    /// Return a normalized copy
    func normalized() -> EmotionDistribution {
        var copy = self
        copy.normalize()
        return copy
    }

    /// Merge with another distribution using confidence-weighted averaging.
    /// `weight` controls how much `other` contributes (0 = ignore other, 1 = equal weight).
    func merged(with other: EmotionDistribution, weight: Double = 1.0) -> EmotionDistribution {
        let selfWeight = confidence
        let otherWeight = other.confidence * weight
        let totalW = selfWeight + otherWeight

        guard totalW > 0 else { return .uniform }

        let merged = zip(probabilities, other.probabilities).map { a, b in
            (a * selfWeight + b * otherWeight) / totalW
        }
        return EmotionDistribution(
            probabilities: merged,
            sourceCount: sourceCount + other.sourceCount
        ).normalized()
    }

    /// Create a distribution with a single dominant emotion
    static func peaked(emotion: Sentiment, probability: Double = 0.7) -> EmotionDistribution {
        let idx = emotions.firstIndex(of: emotion) ?? 11
        let remaining = (1.0 - probability) / 11.0
        var probs = Array(repeating: remaining, count: 12)
        probs[idx] = probability
        return EmotionDistribution(probabilities: probs)
    }

    /// Create from a sparse dictionary of emotion → probability
    static func from(_ dict: [Sentiment: Double]) -> EmotionDistribution {
        var probs = Array(repeating: 0.01, count: 12)  // small floor
        for (emotion, prob) in dict {
            if let idx = emotions.firstIndex(of: emotion) {
                probs[idx] += prob
            }
        }
        return EmotionDistribution(probabilities: probs).normalized()
    }

    // MARK: - Subscript

    subscript(emotion: Sentiment) -> Double {
        get {
            guard let idx = Self.emotions.firstIndex(of: emotion) else { return 0 }
            return probabilities[idx]
        }
        set {
            guard let idx = Self.emotions.firstIndex(of: emotion) else { return }
            probabilities[idx] = max(0, newValue)
        }
    }
}
