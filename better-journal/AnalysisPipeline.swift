//
//  AnalysisPipeline.swift
//  better-journal
//
//  Orchestrates the complete mood detection pipeline:
//    Layer 1: Per-modality signal extraction → ModalitySignal + EmotionDistribution
//    Layer 2: Temperature-scaled calibration
//    Layer 3: Late Fusion (distribution merge + Bayesian VA fusion)
//    Layer 4: Kalman temporal smoothing
//    Layer 5: Personal baseline normalization
//    Layer 6: (External) Personality trait derivation
//
//  Runs entirely on-device. Background-safe via actor isolation.
//

import Foundation
import PencilKit
import UIKit

actor AnalysisPipeline {

    // MARK: - Sub-Engines

    private let imageEngine = ImageAnalysisEngine()
    private let drawingEngine = DrawingAnalysisEngine()
    private let fusionEngine: MoodFusionEngine

    // MARK: - Persisted State

    private var kalmanState: KalmanState
    private var baseline: UserBaseline
    private var calibration: CalibrationLayer

    // MARK: - Init

    init(
        kalmanState: KalmanState = .initial,
        baseline: UserBaseline = UserBaseline(),
        calibration: CalibrationLayer = .initial
    ) {
        self.kalmanState = kalmanState
        self.baseline = baseline
        self.calibration = calibration
        self.fusionEngine = MoodFusionEngine(calibration: calibration)
    }

    // MARK: - Full Pipeline

    /// Run the complete pipeline for a journal entry.
    /// Returns a MoodScore with full EmotionDistribution + dimensional values.
    func analyze(
        title: String,
        content: String,
        photoIDs: [UUID],
        drawing: PKDrawing?,
        canvasSize: CGSize
    ) async -> MoodScore {

        // ─── Layer 1: Signal Extraction (concurrent) ───

        async let textSignalTask = SentimentAnalyzer.analyzeSignal(title: title, content: content)
        async let imageSignalsTask = analyzeImages(photoIDs: photoIDs)

        let drawingSignal: ModalitySignal?
        if let drawing, !drawing.strokes.isEmpty {
            drawingSignal = await drawingEngine.analyze(drawing: drawing, canvasSize: canvasSize)
        } else {
            drawingSignal = nil
        }

        let textSignal = await textSignalTask
        let imageSignals = await imageSignalsTask

        // Collect all available signals
        var signals: [ModalitySignal] = []
        if let ts = textSignal { signals.append(ts) }

        // For multiple images, pick the one with highest confidence
        if let bestImage = imageSignals.max(by: { $0.confidence < $1.confidence }) {
            signals.append(bestImage)
        }
        if let ds = drawingSignal { signals.append(ds) }

        // ─── Layer 2 + 3: Calibration + Late Fusion ───

        let fused = await fusionEngine.fuse(signals: signals)

        // ─── Layer 4: Kalman Temporal Smoothing ───

        let now = Date()
        var ks = kalmanState
        ks.step(
            observedValence: fused.valence,
            observedArousal: fused.arousal,
            observedValenceVariance: fused.valenceVariance,
            observedArousalVariance: fused.arousalVariance,
            baselineValence: baseline.meanValence,
            baselineArousal: baseline.meanArousal,
            now: now
        )
        kalmanState = ks

        let smoothedValence = kalmanState.valence.mu
        let smoothedArousal = kalmanState.arousal.mu

        // ─── Layer 5: Personal Baseline Normalization ───

        var bl = baseline
        bl.update(valence: smoothedValence, arousal: smoothedArousal)
        baseline = bl
        let zScore = baseline.zScore(valence: smoothedValence)
        let label: String? = zScore != nil ? UserBaseline.label(forZScore: zScore) : nil

        // ─── Assemble MoodScore ───

        let primarySentiment = fused.emotionDistribution.dominantEmotion

        return MoodScore(
            emotionDistribution: fused.emotionDistribution,
            topEmotions: fused.topEmotions,
            userConfirmedEmotion: nil,
            valence: smoothedValence,
            arousal: smoothedArousal,
            valenceUncertainty: sqrt(kalmanState.valence.variance),
            arousalUncertainty: sqrt(kalmanState.arousal.variance),
            overallConfidence: fused.confidence,
            contributions: fused.contributions,
            baselineZScore: zScore,
            baselineLabel: label,
            primarySentiment: primarySentiment.rawValue,
            timestamp: now,
            hadConflict: fused.hadConflict
        )
    }

    // MARK: - State Accessors

    func getKalmanState() -> KalmanState { kalmanState }
    func getBaseline() -> UserBaseline { baseline }
    func getCalibration() -> CalibrationLayer { calibration }

    func restore(kalman: KalmanState, baseline: UserBaseline, calibration: CalibrationLayer) {
        self.kalmanState = kalman
        self.baseline = baseline
        self.calibration = calibration
    }

    // MARK: - Image Loading

    private func analyzeImages(photoIDs: [UUID]) async -> [ModalitySignal] {
        let images = photoIDs.compactMap { PhotoStorageManager.shared.loadImage(id: $0) }
        guard !images.isEmpty else { return [] }
        return await imageEngine.analyze(images: images)
    }
}
