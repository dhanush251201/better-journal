//
//  MoodFusionEngine.swift
//  better-journal
//
//  Late Fusion Engine — merges EmotionDistributions from
//  multiple modalities using confidence-weighted averaging.
//
//  Architecture:
//    1. Calibrate each modality's signal (temperature scaling)
//    2. Merge EmotionDistributions with modality-specific weights
//    3. Also fuse valence/arousal via Bayesian precision-weighting
//    4. Detect conflicts (when modalities disagree on top emotion)
//    5. Output final distribution + top-K candidates
//

import Foundation

// MARK: - Late Fusion Engine

actor MoodFusionEngine {

    private let calibration: CalibrationLayer

    /// Modality trust weights — how much each modality is trusted for emotions.
    /// Text is most reliable for specific emotions; media for energy/arousal.
    private let modalityWeights: [ModalityType: Double] = [
        .text: 1.0,      // highest trust for emotion labels
        .image: 0.7,     // good for energy/valence, less for specifics
        .drawing: 0.5    // kinematic data is informative but noisy
    ]

    init(calibration: CalibrationLayer = .initial) {
        self.calibration = calibration
    }

    // MARK: - Fuse

    /// Late fusion of all available modality signals.
    /// Returns fused dimensional values + emotion distribution + top candidates.
    func fuse(signals: [ModalitySignal]) -> (
        valence: Double,
        arousal: Double,
        valenceVariance: Double,
        arousalVariance: Double,
        confidence: Double,
        contributions: [ModalityContribution],
        hadConflict: Bool,
        emotionDistribution: EmotionDistribution,
        topEmotions: [EmotionCandidate]
    ) {
        let calibrated = signals.map { calibration.calibrate($0) }

        guard !calibrated.isEmpty else {
            return (0, 0.35, 0.25, 0.04, 0, [], false, .uniform,
                    [EmotionCandidate(emotion: "neutral", probability: 1.0)])
        }

        // ─── 1. Emotion Distribution Fusion ───

        var fusedDist = EmotionDistribution.uniform
        var firstMerge = true

        for signal in calibrated {
            let weight = modalityWeights[signal.modality] ?? 0.5
            let effectiveWeight = weight * signal.confidence

            if firstMerge {
                // Start with the first signal's distribution, weighted
                var scaledProbs = signal.emotionDistribution.probabilities.map { $0 * effectiveWeight }
                let uniformFloor = (1.0 - effectiveWeight) / 12.0
                scaledProbs = scaledProbs.map { $0 + uniformFloor }
                fusedDist = EmotionDistribution(probabilities: scaledProbs).normalized()
                firstMerge = false
            } else {
                fusedDist = fusedDist.merged(with: signal.emotionDistribution, weight: effectiveWeight)
            }
        }

        fusedDist.normalize()

        // ─── 2. Valence/Arousal Fusion (Bayesian) ───

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

        // Arousal in logit-space
        let fusedArousal: Double
        let fusedArousalVar: Double

        let arousalLogits = calibrated.map { logit(clamp($0.arousal, lo: 0.01, hi: 0.99)) }
        if totalPrecisionV > 0 {
            let fusedLogit = zip(calibrated, arousalLogits).map { signal, logitA in
                signal.precision * logitA
            }.reduce(0, +) / totalPrecisionV
            fusedArousal = sigmoid(fusedLogit)
            fusedArousalVar = 1.0 / totalPrecisionV
        } else {
            fusedArousal = 0.35
            fusedArousalVar = 0.04
        }

        // ─── 3. Conflict Detection ───

        // Check valence disagreement — only flag when modalities truly contradict
        // (e.g., one strongly positive, the other strongly negative)
        let valences = calibrated.map(\.valence)
        let maxDisagreement = (valences.max() ?? 0) - (valences.min() ?? 0)
        let valenceConflict = maxDisagreement > 1.4

        let hadConflict = valenceConflict
        let conflictPenalty = hadConflict ? max(0.3, 1.0 - maxDisagreement / 2.0) : 1.0

        // ─── 4. Overall Confidence ───

        let rawConfidence = fusedDist.confidence
        let confidence = min(0.95, max(0, rawConfidence * conflictPenalty))

        // ─── 5. Top-K Candidates ───

        let topK = fusedDist.topK(3)
        let topEmotions = topK.map {
            EmotionCandidate(emotion: $0.emotion.rawValue, probability: $0.probability)
        }

        // ─── 6. Per-Modality Contributions ───

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
                keyFeatures: Array(topFeatures),
                emotionDistribution: signal.emotionDistribution
            )
        }

        return (
            clamp(fusedValence, lo: -1, hi: 1),
            clamp(fusedArousal, lo: 0, hi: 1),
            fusedValenceVar,
            fusedArousalVar,
            confidence,
            contributions,
            hadConflict,
            fusedDist,
            topEmotions
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
