//
//  UserBaseline.swift
//  better-journal
//
//  Per-user rolling baseline using Welford's online algorithm.
//  Enables z-score normalization so that "sad for Alice"
//  is different from "sad for Bob" — all on-device.
//

import Foundation

// MARK: - User Baseline

/// Incrementally maintained running mean and variance for valence and arousal.
/// Uses Welford's online algorithm (numerically stable, O(1) per update).
struct UserBaseline: Codable, Sendable, Equatable {

    // MARK: - State

    private(set) var count: Int = 0
    private(set) var meanValence: Double = 0
    private(set) var meanArousal: Double = 0
    private(set) var m2Valence: Double = 0          // Σ(x - μ)² accumulator
    private(set) var m2Arousal: Double = 0

    // MARK: - Derived

    var varianceValence: Double {
        count > 1 ? m2Valence / Double(count - 1) : 0.25   // prior σ² = 0.25 (σ = 0.5)
    }
    var varianceArousal: Double {
        count > 1 ? m2Arousal / Double(count - 1) : 0.04   // prior σ² = 0.04 (σ = 0.2)
    }
    var stdValence: Double { sqrt(varianceValence) }
    var stdArousal: Double { sqrt(varianceArousal) }

    /// Minimum data points before baseline normalization activates.
    static let activationThreshold = 10

    /// Whether we have enough data to produce meaningful z-scores.
    var isActive: Bool { count >= Self.activationThreshold }

    // MARK: - Update (Welford's)

    mutating func update(valence: Double, arousal: Double) {
        count += 1
        // Valence
        let deltaV = valence - meanValence
        meanValence += deltaV / Double(count)
        let delta2V = valence - meanValence
        m2Valence += deltaV * delta2V
        // Arousal
        let deltaA = arousal - meanArousal
        meanArousal += deltaA / Double(count)
        let delta2A = arousal - meanArousal
        m2Arousal += deltaA * delta2A
    }

    // MARK: - Z-Score

    /// Compute z-score relative to the user's personal baseline.
    /// Returns `nil` if baseline is not yet active (< 10 data points).
    func zScore(valence: Double) -> Double? {
        guard isActive, stdValence > 1e-6 else { return nil }
        return (valence - meanValence) / stdValence
    }

    func zScore(arousal: Double) -> Double? {
        guard isActive, stdArousal > 1e-6 else { return nil }
        return (arousal - meanArousal) / stdArousal
    }

    // MARK: - User-Facing Label

    /// Map a valence z-score to a human-readable relative mood label.
    static func label(forZScore z: Double?) -> String {
        guard let z else { return "Assessing your rhythm…" }
        switch z {
        case 1.5...:             return "Unusually positive"
        case 0.5..<1.5:          return "Above your baseline"
        case -0.5..<0.5:         return "Within your rhythm"
        case -1.5 ..< -0.5:      return "Below your baseline"
        default:                 return "Notably low"
        }
    }
}
