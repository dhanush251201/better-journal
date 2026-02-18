//
//  MoodFusionEngine.swift
//  better-journal
//
//  Precision-weighted Bayesian fusion with conflict detection.
//  Replaces naive weighted average. No static modality weights.
//  Each modality's influence is determined solely by its calibrated
//  uncertainty (σ) — precise modalities naturally dominate.
//

import Foundation

// MARK: - Bayesian Fusion Engine

actor MoodFusionEngine {

    private let calibration: CalibrationLayer

    init(calibration: CalibrationLayer = .initial) {
        self.calibration = calibration
    }

    // MARK: - Fuse

    /// Precision-weighted Bayesian fusion of all available modality signals.
    ///
    /// Model: each modality produces  v_i ~ N(μ_true, σ_i²).
    /// Posterior:
    ///   μ_fused  = Σ(τ_i × v_i) / Σ(τ_i)      where τ_i = 1/σ_i²
    ///   σ_fused  = 1 / √Σ(τ_i)
    ///
    /// Arousal is fused in logit-space (since it's bounded [0,1]).
    func fuse(signals: [ModalitySignal]) -> (
        valence: Double,
        arousal: Double,
        valenceVariance: Double,
        arousalVariance: Double,
        confidence: Double,
        contributions: [ModalityContribution],
        hadConflict: Bool
    ) {
        // Calibrate all signals
        let calibrated = signals.map { calibration.calibrate($0) }

        guard !calibrated.isEmpty else {
            return (0, 0.35, 0.25, 0.04, 0, [], false)
        }

        // --- Valence fusion (unbounded [-1, 1], direct space) ---
        let totalPrecisionV = calibrated.map(\.precision).reduce(0, +)
        let fusedValence: Double
        let fusedValenceVar: Double

        if totalPrecisionV > 0 {
            fusedValence = calibrated.map { $0.precision * $0.valence }.reduce(0, +) / totalPrecisionV
            fusedValenceVar = 1.0 / totalPrecisionV
        } else {
            fusedValence = 0
            fusedValenceVar = 0.25
        }

        // --- Arousal fusion (bounded [0, 1], logit-space) ---
        let fusedArousal: Double
        let fusedArousalVar: Double

        let arousalLogits = calibrated.map { logit(clamp($0.arousal, lo: 0.01, hi: 0.99)) }
        // Use same precision weights for arousal
        let totalPrecisionA = totalPrecisionV  // same modalities
        if totalPrecisionA > 0 {
            let fusedLogit = zip(calibrated, arousalLogits).map { signal, logitA in
                signal.precision * logitA
            }.reduce(0, +) / totalPrecisionA
            fusedArousal = sigmoid(fusedLogit)
            fusedArousalVar = 1.0 / totalPrecisionA
        } else {
            fusedArousal = 0.35
            fusedArousalVar = 0.04
        }

        // --- Conflict detection ---
        let valences = calibrated.map(\.valence)
        let maxDisagreement = (valences.max() ?? 0) - (valences.min() ?? 0)
        let hadConflict = maxDisagreement > 1.0
        let conflictPenalty = hadConflict ? max(0.3, 1.0 - maxDisagreement / 2.0) : 1.0

        // --- Overall confidence ---
        // Derived from fused precision, conflict-penalized, capped at 0.95
        let rawConfidence = 1.0 - sqrt(fusedValenceVar)
        let confidence = min(0.95, max(0, rawConfidence * conflictPenalty))

        // --- Per-modality contributions (for explainability) ---
        let contributions = calibrated.map { signal -> ModalityContribution in
            let influence = totalPrecisionV > 0 ? signal.precision / totalPrecisionV : 0
            let topFeatures = zip(signal.featureLabels, signal.featureVector)
                .sorted { abs($0.1) > abs($1.1) }
                .prefix(3)
                .map(\.0)

            return ModalityContribution(
                modality: signal.modality,
                valence: signal.valence,
                arousal: signal.arousal,
                uncertainty: signal.uncertainty,
                calibratedConfidence: signal.confidence,
                influence: influence,
                keyFeatures: Array(topFeatures)
            )
        }

        return (
            clamp(fusedValence, lo: -1, hi: 1),
            clamp(fusedArousal, lo: 0, hi: 1),
            fusedValenceVar,
            fusedArousalVar,
            confidence,
            contributions,
            hadConflict
        )
    }

    // MARK: - Math

    private func logit(_ p: Double) -> Double {
        log(p / (1 - p))
    }

    private func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }

    private func clamp(_ v: Double, lo: Double, hi: Double) -> Double {
        Swift.min(hi, Swift.max(lo, v))
    }
}
