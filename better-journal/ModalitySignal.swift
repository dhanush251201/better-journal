//
//  ModalitySignal.swift
//  better-journal
//
//  Uniform output contract for all modality extractors.
//  Every modality MUST produce one of these before fusion.
//

import Foundation

// MARK: - Modality Type

enum ModalityType: String, Codable, Sendable, CaseIterable {
    case text
    case image
    case drawing
}

// MARK: - Modality Signal

/// A calibration-ready, uncertainty-carrying signal from a single modality.
///
/// - `valence`: Continuous affect value in [-1, 1].
/// - `arousal`: Continuous activation value in [0, 1].
/// - `confidence`: How reliable this observation is (pre-calibration). [0, 1].
/// - `uncertainty`: Standard deviation of the estimate (σ). Must be ≥ 0.1.
/// - `featureVector` / `featureLabels`: Raw features for explainability.
struct ModalitySignal: Codable, Sendable, Equatable {
    let modality: ModalityType
    let valence: Double
    let arousal: Double
    let confidence: Double
    let uncertainty: Double
    let featureVector: [Double]
    let featureLabels: [String]

    // MARK: - Factory

    /// Create a signal with enforced invariants.
    static func make(
        modality: ModalityType,
        valence: Double,
        arousal: Double,
        confidence: Double,
        uncertainty: Double,
        featureVector: [Double] = [],
        featureLabels: [String] = []
    ) -> ModalitySignal {
        ModalitySignal(
            modality: modality,
            valence: clamp(valence, lo: -1, hi: 1),
            arousal: clamp(arousal, lo: 0, hi: 1),
            confidence: clamp(confidence, lo: 0, hi: 1),
            uncertainty: max(0.1, uncertainty),          // floor at 0.1 — no infinite precision
            featureVector: featureVector,
            featureLabels: featureLabels
        )
    }

    /// Precision (inverse variance). Used by Bayesian fusion.
    var precision: Double { 1.0 / (uncertainty * uncertainty) }

    // MARK: - Helpers

    private static func clamp(_ v: Double, lo: Double, hi: Double) -> Double {
        Swift.min(hi, Swift.max(lo, v))
    }
}
