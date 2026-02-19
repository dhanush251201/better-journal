//
//  DrawingAnalysisEngine.swift
//  better-journal
//
//  Kinematic & geometric analysis of PencilKit drawings.
//  Extracts stroke features (pressure, velocity, jaggedness, coverage,
//  color) and maps them to an EmotionDistribution via a research-based
//  feature-to-emotion weight matrix.
//
//  Based on: Kang (2014), Kim (2018) affective computing literature.
//

import PencilKit
import UIKit

// MARK: - Drawing Features

struct DrawingFeatures: Sendable {
    let meanPressure: Double
    let pressureStdDev: Double
    let meanVelocity: Double
    let velocityStdDev: Double
    let strokeDensity: Double
    let coverage: Double
    let spatialEntropy: Double
    let colorVariance: Double
    let jaggedness: Double       // NEW: angular change rate
    let warmColorRatio: Double   // NEW: warm vs cool colors

    static let labels = [
        "pressure", "pressure variability", "speed", "speed variability",
        "stroke density", "canvas coverage", "spatial spread", "color variety",
        "jaggedness", "warm colors"
    ]
}

// MARK: - Engine

actor DrawingAnalysisEngine {

    // MARK: - Feature-to-Emotion Weight Matrix
    //
    // Each row maps a feature to emotion category weights.
    // Features: [pressure, pressureVar, velocity, velocityVar,
    //            density, coverage, entropy, colorVar, jaggedness, warmColors]
    //
    // Emotions: [happy, grateful, calm, excited, hopeful, reflective,
    //            nostalgic, anxious, sad, frustrated, stressed, neutral]

    private let emotionMatrix: [[Double]] = [
        // Feature:        hap   gra   cal   exc   hop   ref   nos   anx   sad   fru   str   neu
        /* pressure    */ [ 0.1,  0.0, -0.2,  0.15, 0.0,  0.0,  0.0,  0.15, -0.1, 0.3,  0.25, 0.0],
        /* pressVar    */ [ 0.0,  0.0, -0.15, 0.1,  0.0,  0.0,  0.0,  0.2,  0.0,  0.25, 0.15, 0.0],
        /* velocity    */ [ 0.15, 0.0, -0.2,  0.3,  0.0,  0.0,  0.0,  0.15, -0.15, 0.2, 0.1,  0.0],
        /* velVar      */ [ 0.0,  0.0, -0.1,  0.15, 0.0,  0.0,  0.0,  0.25, 0.0,  0.15, 0.2,  0.0],
        /* density     */ [ 0.1,  0.0,  0.0,  0.15, 0.0,  0.0,  0.0,  0.1,  0.0,  0.15, 0.1,  0.0],
        /* coverage    */ [ 0.2,  0.1,  0.0,  0.25, 0.1,  0.0,  0.0, -0.1, -0.15, 0.0,  0.0,  0.0],
        /* entropy     */ [ 0.15, 0.0,  0.1,  0.1,  0.05, 0.1,  0.0, -0.1, -0.1,  0.0,  0.0,  0.0],
        /* colorVar    */ [ 0.2,  0.0,  0.0,  0.25, 0.1,  0.0,  0.0,  0.0,  -0.1, 0.0,  0.0, -0.1],
        /* jaggedness  */ [-0.15, 0.0, -0.25, 0.0,  0.0,  0.0,  0.0,  0.3,  0.0,  0.35, 0.25, 0.0],
        /* warmColors  */ [ 0.3,  0.15, 0.0,  0.2,  0.1,  0.0,  0.0,  0.0,  -0.2, 0.0,  0.0,  0.0],
    ]

    private let bias: [Double] = [
        // hap   gra   cal   exc   hop   ref   nos  anx   sad   fru   str   neu
        0.08, 0.02, 0.1, 0.05, 0.03, 0.05, 0.02, 0.02, 0.02, 0.02, 0.02, 0.08
    ]

    // MARK: - Public API

    func analyze(drawing: PKDrawing, canvasSize: CGSize) -> ModalitySignal {
        let strokes = drawing.strokes
        guard !strokes.isEmpty else {
            return ModalitySignal.make(
                modality: .drawing, valence: 0, arousal: 0.3,
                confidence: 0, uncertainty: 0.6,
                emotionDistribution: .uniform
            )
        }

        let features = extractFeatures(strokes: strokes, drawing: drawing, canvasSize: canvasSize)

        // Compute emotion distribution: softmax(W × features + b)
        let featureArray = features.asArray
        var rawScores = Array(repeating: 0.0, count: 12)

        for (fIdx, fVal) in featureArray.enumerated() {
            for eIdx in 0..<12 {
                rawScores[eIdx] += emotionMatrix[fIdx][eIdx] * fVal
            }
        }
        for eIdx in 0..<12 {
            rawScores[eIdx] += bias[eIdx]
        }

        // Softmax
        let maxScore = rawScores.max() ?? 0
        let expScores = rawScores.map { exp($0 - maxScore) }
        let sumExp = expScores.reduce(0, +)
        let probs = expScores.map { $0 / sumExp }

        let dist = EmotionDistribution(probabilities: probs)

        // Confidence: sigmoid of stroke count × coverage
        let strokeFactor = min(1.0, Double(strokes.count) / 15.0)
        let coverageFactor = features.coverage
        let confidence = sigmoid((strokeFactor * coverageFactor) * 4 - 2)

        let uncertainty = max(0.15, 0.5 * (1 - confidence) + 0.1)

        // Feature labels for explainability
        var humanLabels: [String] = []
        var humanFeatures: [Double] = []

        if features.meanPressure > 0.6 {
            humanLabels.append("heavy pressure")
            humanFeatures.append(features.meanPressure)
        } else if features.meanPressure < 0.25 {
            humanLabels.append("light strokes")
            humanFeatures.append(features.meanPressure)
        }
        if features.jaggedness > 0.5 {
            humanLabels.append("jagged strokes")
            humanFeatures.append(features.jaggedness)
        }
        if features.meanVelocity > 0.5 {
            humanLabels.append("fast strokes")
            humanFeatures.append(features.meanVelocity)
        } else if features.meanVelocity < 0.15 {
            humanLabels.append("slow, deliberate")
            humanFeatures.append(features.meanVelocity)
        }
        if features.coverage > 0.5 {
            humanLabels.append("expressive coverage")
            humanFeatures.append(features.coverage)
        }
        if features.warmColorRatio > 0.6 {
            humanLabels.append("warm colors")
            humanFeatures.append(features.warmColorRatio)
        } else if features.warmColorRatio < 0.2 {
            humanLabels.append("cool/dark tones")
            humanFeatures.append(features.warmColorRatio)
        }
        if features.colorVariance > 0.3 {
            humanLabels.append("colorful palette")
            humanFeatures.append(features.colorVariance)
        }

        return ModalitySignal.make(
            modality: .drawing,
            valence: dist.valence,
            arousal: dist.arousal,
            confidence: confidence,
            uncertainty: uncertainty,
            emotionDistribution: dist,
            featureVector: humanFeatures,
            featureLabels: humanLabels
        )
    }

    // MARK: - Feature Extraction

    private var featureArray: [Double] { [] }

    private func extractFeatures(strokes: [PKStroke], drawing: PKDrawing, canvasSize: CGSize) -> DrawingFeatures {

        // 1. Pressure statistics
        var pressures: [Double] = []
        for stroke in strokes {
            let path = stroke.path
            for i in 0..<path.count {
                pressures.append(min(1.0, Double(path[i].force) / 3.5))
            }
        }
        let (meanP, stdP) = meanAndStd(pressures)

        // 2. Velocity statistics
        var velocities: [Double] = []
        for stroke in strokes {
            let path = stroke.path
            guard path.count > 1 else { continue }
            for i in 1..<path.count {
                let dx = Double(path[i].location.x - path[i-1].location.x)
                let dy = Double(path[i].location.y - path[i-1].location.y)
                let dt = max(0.001, path[i].timeOffset - path[i-1].timeOffset)
                velocities.append(sqrt(dx*dx + dy*dy) / dt)
            }
        }
        let (meanV, stdV) = meanAndStd(velocities)
        let normMeanV = min(1.0, meanV / 1000.0)
        let normStdV = min(1.0, stdV / 1000.0)

        // 3. Stroke density
        let canvasArea = max(1, Double(canvasSize.width * canvasSize.height))
        let density = min(1.0, Double(strokes.count) / (canvasArea / 5000.0))

        // 4. Coverage
        let bounds = drawing.bounds
        let coverage = min(1.0, Double(bounds.width * bounds.height) / canvasArea)

        // 5. Spatial entropy (4×4 grid)
        let entropy = computeSpatialEntropy(strokes: strokes, canvasSize: canvasSize, gridSize: 4)

        // 6. Color variance (HSB hue)
        let colorVar = computeColorVariance(strokes: strokes)

        // 7. Jaggedness: mean angular change between consecutive segments
        let jagged = computeJaggedness(strokes: strokes)

        // 8. Warm color ratio
        let warmRatio = computeWarmColorRatio(strokes: strokes)

        return DrawingFeatures(
            meanPressure: meanP,
            pressureStdDev: stdP,
            meanVelocity: normMeanV,
            velocityStdDev: normStdV,
            strokeDensity: density,
            coverage: coverage,
            spatialEntropy: entropy,
            colorVariance: colorVar,
            jaggedness: jagged,
            warmColorRatio: warmRatio
        )
    }

    // MARK: - Jaggedness (angular change)

    private func computeJaggedness(strokes: [PKStroke]) -> Double {
        var totalAngleChange = 0.0
        var segmentCount = 0

        for stroke in strokes {
            let path = stroke.path
            guard path.count > 2 else { continue }

            for i in 2..<path.count {
                let dx1 = Double(path[i-1].location.x - path[i-2].location.x)
                let dy1 = Double(path[i-1].location.y - path[i-2].location.y)
                let dx2 = Double(path[i].location.x - path[i-1].location.x)
                let dy2 = Double(path[i].location.y - path[i-1].location.y)

                let angle1 = atan2(dy1, dx1)
                let angle2 = atan2(dy2, dx2)
                var diff = abs(angle2 - angle1)
                if diff > .pi { diff = 2 * .pi - diff }

                totalAngleChange += diff
                segmentCount += 1
            }
        }

        guard segmentCount > 0 else { return 0 }
        let meanAngle = totalAngleChange / Double(segmentCount)
        // Normalize: π/4 (45°) mean change = 0.5 jaggedness
        return min(1.0, meanAngle / (.pi / 2))
    }

    // MARK: - Warm Color Ratio

    private func computeWarmColorRatio(strokes: [PKStroke]) -> Double {
        guard !strokes.isEmpty else { return 0.5 }
        var warmCount = 0
        var totalCount = 0

        for stroke in strokes {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            stroke.ink.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            totalCount += 1

            // Warm: red (0-0.1, 0.9-1.0), orange (0.05-0.15), yellow (0.1-0.2)
            if h < 0.2 || h > 0.85 {
                warmCount += 1
            }
        }

        return totalCount > 0 ? Double(warmCount) / Double(totalCount) : 0.5
    }

    // MARK: - Spatial Entropy

    private func computeSpatialEntropy(strokes: [PKStroke], canvasSize: CGSize, gridSize: Int) -> Double {
        var grid = Array(repeating: 0, count: gridSize * gridSize)
        var total = 0

        let cellW = max(1.0, Double(canvasSize.width) / Double(gridSize))
        let cellH = max(1.0, Double(canvasSize.height) / Double(gridSize))

        for stroke in strokes {
            let center = stroke.path.interpolatedLocation(at: 0)
            let col = min(gridSize - 1, max(0, Int(Double(center.x) / cellW)))
            let row = min(gridSize - 1, max(0, Int(Double(center.y) / cellH)))
            grid[row * gridSize + col] += 1
            total += 1
        }

        guard total > 0 else { return 0 }
        let maxEntropy = log2(Double(gridSize * gridSize))
        var entropy = 0.0
        for count in grid where count > 0 {
            let p = Double(count) / Double(total)
            entropy -= p * log2(p)
        }
        return maxEntropy > 0 ? entropy / maxEntropy : 0
    }

    // MARK: - Color Variance

    private func computeColorVariance(strokes: [PKStroke]) -> Double {
        guard !strokes.isEmpty else { return 0 }
        var hues: [Double] = []
        for stroke in strokes {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            stroke.ink.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            if s > 0.1 {
                hues.append(Double(h))
            }
        }
        if hues.count < 2 { return 0 }
        let (_, std) = meanAndStd(hues)
        return min(1.0, std * 3.0)
    }

    // MARK: - DrawingFeatures array accessor

    // MARK: - Math Helpers

    private func meanAndStd(_ values: [Double]) -> (mean: Double, std: Double) {
        guard !values.isEmpty else { return (0.5, 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        if values.count < 2 { return (mean, 0) }
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        return (mean, sqrt(variance))
    }

    private func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }
}

// Extension to get features as array
extension DrawingFeatures {
    var asArray: [Double] {
        [meanPressure, pressureStdDev, meanVelocity, velocityStdDev,
         strokeDensity, coverage, spatialEntropy, colorVariance,
         jaggedness, warmColorRatio]
    }
}
