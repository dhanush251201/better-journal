//
//  CalibrationLayer.swift
//  better-journal
//
//  Temperature scaling per modality.
//  Maps raw (uncalibrated) confidence to well-calibrated probability.
//  Persisted locally. Adapts over time if user provides corrections.
//

import Foundation

// MARK: - Calibration Layer

struct CalibrationLayer: Codable, Sendable, Equatable {

    /// Temperature parameters per modality.
    /// T > 1 softens overconfident signals (most engines need this initially).
    /// T < 1 sharpens underconfident ones.
    var temperatures: [ModalityType: Double]

    // MARK: - Factory

    /// Conservative initial temperatures that soften all modalities.
    static let initial = CalibrationLayer(temperatures: [
        .text: 1.2,
        .image: 1.8,
        .drawing: 2.0
    ])

    // MARK: - Calibrate

    /// Apply temperature scaling to a raw modality signal.
    func calibrate(_ signal: ModalitySignal) -> ModalitySignal {
        let T = temperatures[signal.modality] ?? 1.5

        // Temperature-scaled logistic calibration
        let clampedConf = max(1e-6, min(1 - 1e-6, signal.confidence))
        let logit = log(clampedConf / (1 - clampedConf))
        let calibrated = 1.0 / (1.0 + exp(-logit / T))

        // Scale uncertainty proportionally — higher T = more cautious
        let scaledUncertainty = max(0.1, signal.uncertainty * sqrt(T))

        return ModalitySignal.make(
            modality: signal.modality,
            valence: signal.valence,
            arousal: signal.arousal,
            confidence: calibrated,
            uncertainty: scaledUncertainty,
            featureVector: signal.featureVector,
            featureLabels: signal.featureLabels
        )
    }

    // MARK: - Adaptive Update

    /// Update temperature for a single modality using binary search on NLL.
    /// Called after accumulating ≥ 20 entries with user-corrected mood labels.
    ///
    /// - `predictions`: raw confidences from the engine
    /// - `outcomes`: 1.0 if the engine's top prediction was correct, 0.0 otherwise
    mutating func adaptTemperature(
        for modality: ModalityType,
        predictions: [Double],
        outcomes: [Double]
    ) {
        guard predictions.count >= 20, predictions.count == outcomes.count else { return }

        var lo = 0.5
        var hi = 4.0

        // Binary search for T minimizing negative log-likelihood
        for _ in 0..<20 {
            let mid = (lo + hi) / 2.0
            let nllLow = nll(predictions: predictions, outcomes: outcomes, T: lo)
            let nllMid = nll(predictions: predictions, outcomes: outcomes, T: mid)

            if nllLow < nllMid {
                hi = mid
            } else {
                lo = mid
            }
        }

        temperatures[modality] = (lo + hi) / 2.0
    }

    private func nll(predictions: [Double], outcomes: [Double], T: Double) -> Double {
        var total = 0.0
        for i in 0..<predictions.count {
            let p = max(1e-6, min(1 - 1e-6, predictions[i]))
            let logit = log(p / (1 - p))
            let calibrated = 1.0 / (1.0 + exp(-logit / T))
            let y = outcomes[i]
            total -= y * log(calibrated + 1e-8) + (1 - y) * log(1 - calibrated + 1e-8)
        }
        return total / Double(predictions.count)
    }
}
