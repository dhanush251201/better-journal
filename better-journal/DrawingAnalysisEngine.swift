//
//  DrawingAnalysisEngine.swift
//  better-journal
//
//  Extracts an 8-dimensional feature vector from PencilKit drawings
//  and maps to valence-arousal via a pre-computed regression matrix.
//  Outputs ModalitySignal with proper uncertainty.
//
//  Feature vector: [meanPressure, pressureStdDev, meanVelocity,
//                   velocityStdDev, strokeDensity, coverage,
//                   spatialEntropy, colorVariance]
//

import PencilKit
import UIKit

// MARK: - Drawing Feature Vector

/// The raw 8D feature vector extracted from a drawing.
struct DrawingFeatures: Sendable {
    let meanPressure: Double
    let pressureStdDev: Double
    let meanVelocity: Double
    let velocityStdDev: Double
    let strokeDensity: Double
    let coverage: Double
    let spatialEntropy: Double
    let colorVariance: Double

    var asArray: [Double] {
        [meanPressure, pressureStdDev, meanVelocity, velocityStdDev,
         strokeDensity, coverage, spatialEntropy, colorVariance]
    }

    static let labels = [
        "pressure", "pressure variability", "speed", "speed variability",
        "stroke density", "canvas coverage", "spatial spread", "color variety"
    ]
}

// MARK: - Engine

actor DrawingAnalysisEngine {

    // MARK: - Regression Matrix

    /// Pre-computed 2×8 regression weights + 2×1 bias for mapping
    /// features → (valence, arousal). Derived from published correlations
    /// in affective computing literature (Kang 2014, Kim 2018).
    ///
    /// Output = tanh(W × features + b) for bounded output.
    ///
    /// Row 0 = valence weights, Row 1 = arousal weights.
    private let W: [[Double]] = [
        // valence: coverage+, entropy+, pressure−, pressureVar−, colorVar+, velocity−
        [ -0.15, -0.20,  -0.10, -0.12,  0.05,  0.25,  0.15,  0.20 ],
        // arousal: pressure+, velocity+, density+, coverage+, pressureVar+
        [  0.30,  0.15,   0.25,  0.10,  0.15,  0.20,  0.05,  0.05 ]
    ]

    private let bias: [Double] = [0.05, 0.10]  // slight positive/active priors

    // MARK: - Public API

    func analyze(drawing: PKDrawing, canvasSize: CGSize) -> ModalitySignal {
        let strokes = drawing.strokes
        guard !strokes.isEmpty else {
            return ModalitySignal.make(
                modality: .drawing, valence: 0, arousal: 0.3,
                confidence: 0, uncertainty: 0.6
            )
        }

        // Extract features
        let features = extractFeatures(strokes: strokes, drawing: drawing, canvasSize: canvasSize)

        // Regression: output = tanh(W × features + b)
        let featureArray = features.asArray
        let rawValence = dotProduct(W[0], featureArray) + bias[0]
        let rawArousal = dotProduct(W[1], featureArray) + bias[1]
        let valence = tanh(rawValence)
        let arousal = max(0, min(1, sigmoid(rawArousal)))

        // Confidence: sigmoid of stroke count × coverage
        // Requires meaningful canvas usage for high confidence
        let strokeFactor = min(1.0, Double(strokes.count) / 15.0)
        let coverageFactor = features.coverage
        let confidence = sigmoid((strokeFactor * coverageFactor) * 4 - 2) // sigmoid centered around 0.5

        // Uncertainty: higher when fewer strokes or low coverage
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
        if features.coverage > 0.5 {
            humanLabels.append("expressive coverage")
            humanFeatures.append(features.coverage)
        }
        if features.colorVariance > 0.3 {
            humanLabels.append("colorful palette")
            humanFeatures.append(features.colorVariance)
        } else if features.colorVariance < 0.05 {
            humanLabels.append("monochrome strokes")
            humanFeatures.append(features.colorVariance)
        }
        if features.meanVelocity > 0.6 {
            humanLabels.append("energetic strokes")
            humanFeatures.append(features.meanVelocity)
        }

        return ModalitySignal.make(
            modality: .drawing,
            valence: valence,
            arousal: arousal,
            confidence: confidence,
            uncertainty: uncertainty,
            featureVector: humanFeatures,
            featureLabels: humanLabels
        )
    }

    // MARK: - Feature Extraction

    private func extractFeatures(strokes: [PKStroke], drawing: PKDrawing, canvasSize: CGSize) -> DrawingFeatures {

        // 1. Pressure statistics
        var pressures: [Double] = []
        for stroke in strokes {
            let path = stroke.path
            for i in 0..<path.count {
                // Apple Pencil force range 0–6.67; normalize to [0, 1]
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
        // Normalize velocity: 500 pt/s = 0.5
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

        return DrawingFeatures(
            meanPressure: meanP,
            pressureStdDev: stdP,
            meanVelocity: normMeanV,
            velocityStdDev: normStdV,
            strokeDensity: density,
            coverage: coverage,
            spatialEntropy: entropy,
            colorVariance: colorVar
        )
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
            if s > 0.1 {  // only count chromatic strokes
                hues.append(Double(h))
            }
        }
        if hues.count < 2 { return 0 }
        let (_, std) = meanAndStd(hues)
        return min(1.0, std * 3.0)   // normalize: 0.33 std → 1.0
    }

    // MARK: - Math Helpers

    private func meanAndStd(_ values: [Double]) -> (mean: Double, std: Double) {
        guard !values.isEmpty else { return (0.5, 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        if values.count < 2 { return (mean, 0) }
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        return (mean, sqrt(variance))
    }

    private func dotProduct(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).map(*).reduce(0, +)
    }

    private func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }
}
