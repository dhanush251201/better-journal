//
//  ImageAnalysisEngine.swift
//  better-journal
//
//  On-device image analysis using Vision framework.
//  Outputs ModalitySignal with EmotionDistribution.
//
//  Three sub-analyzers:
//    1. Face Expression: VNDetectFaceLandmarks → smile/frown geometry → emotions
//    2. Color Theory: HSB histogram + Valdez-Mehrabian model → emotions
//    3. Scene Classification: VNClassifyImage → scene-to-emotion mapping
//

import Vision
import UIKit

// MARK: - Engine

actor ImageAnalysisEngine {

    enum AnalysisError: Error { case invalidImage }

    // MARK: - Scene → Emotion Mapping

    /// Maps scene labels to emotion distributions (expanded from OASIS norms)
    private static let sceneEmotions: [String: [Sentiment: Double]] = [
        // Nature (calm, happy)
        "beach":     [.calm: 0.4, .happy: 0.35, .grateful: 0.15],
        "sunset":    [.calm: 0.35, .grateful: 0.3, .reflective: 0.2],
        "sunrise":   [.hopeful: 0.35, .calm: 0.3, .happy: 0.2],
        "garden":    [.calm: 0.4, .happy: 0.25, .grateful: 0.2],
        "flower":    [.happy: 0.35, .calm: 0.3, .grateful: 0.2],
        "lake":      [.calm: 0.5, .reflective: 0.25],
        "park":      [.calm: 0.35, .happy: 0.3],
        "nature":    [.calm: 0.4, .happy: 0.2, .grateful: 0.15],
        "forest":    [.calm: 0.4, .reflective: 0.25],
        "mountain":  [.excited: 0.25, .calm: 0.3, .grateful: 0.2],
        "sky":       [.calm: 0.35, .hopeful: 0.25, .reflective: 0.2],
        "ocean":     [.calm: 0.35, .reflective: 0.25, .excited: 0.15],
        "waterfall": [.excited: 0.3, .calm: 0.25, .happy: 0.2],
        "rainbow":   [.happy: 0.4, .hopeful: 0.35, .excited: 0.15],
        "snow":      [.calm: 0.35, .nostalgic: 0.2, .reflective: 0.2],

        // Social (happy, excited)
        "party":       [.excited: 0.45, .happy: 0.4],
        "celebration": [.excited: 0.4, .happy: 0.4, .grateful: 0.1],
        "wedding":     [.happy: 0.4, .grateful: 0.3, .excited: 0.2],
        "concert":     [.excited: 0.5, .happy: 0.3],
        "playground":  [.happy: 0.4, .excited: 0.3, .nostalgic: 0.15],
        "family":      [.grateful: 0.3, .happy: 0.35, .nostalgic: 0.15],
        "people":      [.neutral: 0.3, .happy: 0.2, .reflective: 0.15],

        // Sport
        "sport":   [.excited: 0.4, .happy: 0.25, .stressed: 0.1],
        "gym":     [.stressed: 0.2, .excited: 0.25, .calm: 0.15],
        "running": [.excited: 0.3, .calm: 0.2, .happy: 0.2],

        // Food
        "food":       [.happy: 0.3, .calm: 0.2, .grateful: 0.2],
        "restaurant": [.happy: 0.3, .calm: 0.2, .excited: 0.15],
        "cake":       [.happy: 0.4, .excited: 0.25, .grateful: 0.15],
        "coffee":     [.calm: 0.35, .happy: 0.2, .reflective: 0.15],

        // Animals
        "pet": [.happy: 0.4, .calm: 0.25, .grateful: 0.2],
        "dog": [.happy: 0.45, .excited: 0.2, .grateful: 0.15],
        "cat": [.calm: 0.35, .happy: 0.3, .grateful: 0.15],

        // Urban (neutral)
        "city":     [.neutral: 0.3, .excited: 0.15, .stressed: 0.15],
        "traffic":  [.stressed: 0.35, .frustrated: 0.3, .anxious: 0.15],
        "office":   [.stressed: 0.25, .neutral: 0.3, .reflective: 0.15],
        "building": [.neutral: 0.4, .reflective: 0.15],

        // Negative
        "rain":     [.sad: 0.3, .reflective: 0.25, .calm: 0.15],
        "storm":    [.anxious: 0.35, .stressed: 0.25, .frustrated: 0.15],
        "dark":     [.sad: 0.3, .anxious: 0.2, .reflective: 0.2],
        "hospital": [.anxious: 0.3, .sad: 0.25, .stressed: 0.2],
        "night":    [.calm: 0.25, .reflective: 0.25, .anxious: 0.15],
        "fire":     [.frustrated: 0.3, .anxious: 0.3, .stressed: 0.2],
    ]

    // MARK: - Public API

    func analyze(image: UIImage) async throws -> ModalitySignal {
        guard let cgImage = image.cgImage else { throw AnalysisError.invalidImage }

        async let scenes = classifyScene(cgImage)
        async let faces = detectFaceLandmarks(cgImage)
        async let colorInfo = analyzeColor(cgImage)

        let (sceneResults, faceResults, colorResult) = try await (scenes, faces, colorInfo)
        return computeSignal(scenes: sceneResults, faces: faceResults, color: colorResult)
    }

    func analyze(images: [UIImage]) async -> [ModalitySignal] {
        await withTaskGroup(of: ModalitySignal?.self) { group in
            for image in images {
                group.addTask { [weak self] in
                    try? await self?.analyze(image: image)
                }
            }
            var results: [ModalitySignal] = []
            for await result in group {
                if let r = result { results.append(r) }
            }
            return results
        }
    }

    // MARK: - Vision: Scene Classification

    private func classifyScene(_ image: CGImage) throws -> [(label: String, prob: Float)] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let results = (request.results as? [VNClassificationObservation]) ?? []
        return results
            .filter { $0.confidence > 0.10 }
            .prefix(15)
            .map { ($0.identifier, $0.confidence) }
    }

    // MARK: - Vision: Face Landmarks → Expression

    private struct FaceResult: Sendable {
        let smileProbability: Double   // [0, 1]
        let frownProbability: Double   // [0, 1]
        let boundingBox: CGRect
    }

    private func detectFaceLandmarks(_ image: CGImage) throws -> [FaceResult] {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let faces = (request.results as? [VNFaceObservation]) ?? []
        return faces.compactMap { face -> FaceResult? in
            guard let outerLips = face.landmarks?.outerLips,
                  outerLips.pointCount >= 6 else {
                return FaceResult(smileProbability: 0.3, frownProbability: 0.2,
                                 boundingBox: face.boundingBox)
            }

            let points = outerLips.normalizedPoints
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            let lipWidth = (xs.max() ?? 0) - (xs.min() ?? 0)
            let lipHeight = max(0.001, (ys.max() ?? 0) - (ys.min() ?? 0))
            let aspectRatio = lipWidth / lipHeight

            // Smiling: aspect ratio > 3.0. Neutral ~2.0. Frown < 1.5
            let smileProb = min(1.0, max(0, (aspectRatio - 1.5) / 3.0))

            // Also check corners: if mouth corners are lower than center → frown
            let leftCorner = points.first?.y ?? 0
            let rightCorner = points.last?.y ?? 0
            let centerY = ys.reduce(0, +) / CGFloat(ys.count)
            let cornerDrop = centerY - min(leftCorner, rightCorner)
            let frownProb = min(1.0, max(0, Double(cornerDrop) * 3.0))

            return FaceResult(smileProbability: smileProb, frownProbability: frownProb,
                             boundingBox: face.boundingBox)
        }
    }

    // MARK: - Color Analysis → Emotion Distribution

    private struct ColorResult: Sendable {
        let hueHistogram: [Double]
        let meanSaturation: Double
        let meanBrightness: Double
        let emotionDist: EmotionDistribution
    }

    private func analyzeColor(_ image: CGImage) async -> ColorResult {
        let width = min(image.width, 64)
        let height = min(image.height, 64)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ColorResult(hueHistogram: Array(repeating: 1.0/12, count: 12),
                             meanSaturation: 0.5, meanBrightness: 0.5,
                             emotionDist: .uniform)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hueHist = Array(repeating: 0.0, count: 12)
        var satSum = 0.0, briSum = 0.0
        let count = width * height

        for i in 0..<count {
            let offset = i * 4
            let r = CGFloat(pixelData[offset]) / 255.0
            let g = CGFloat(pixelData[offset + 1]) / 255.0
            let b = CGFloat(pixelData[offset + 2]) / 255.0

            var h: CGFloat = 0, s: CGFloat = 0, bri: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &bri, alpha: nil)

            let hueBin = min(11, Int(h * 12))
            hueHist[hueBin] += 1
            satSum += Double(s)
            briSum += Double(bri)
        }

        let n = Double(count)
        hueHist = hueHist.map { $0 / n }
        let meanSat = satSum / n
        let meanBri = briSum / n

        // Map color characteristics to emotions using Valdez-Mehrabian
        var emotionProbs: [Sentiment: Double] = [:]

        // Warm, bright, saturated → happy, excited
        let warmBins = hueHist[0] + hueHist[1] + hueHist[11]  // red/orange/magenta
        let coolBins = hueHist[5] + hueHist[6] + hueHist[7]   // cyan/blue/purple
        let greenBins = hueHist[3] + hueHist[4]                // green/teal

        if meanBri > 0.6 && meanSat > 0.4 {
            // Bright & saturated → positive
            emotionProbs[.happy] = (emotionProbs[.happy] ?? 0) + 0.3
            emotionProbs[.excited] = (emotionProbs[.excited] ?? 0) + 0.2
        }
        if meanBri < 0.3 {
            // Dark → sad, reflective
            emotionProbs[.sad] = (emotionProbs[.sad] ?? 0) + 0.3
            emotionProbs[.reflective] = (emotionProbs[.reflective] ?? 0) + 0.2
        }
        if warmBins > 0.3 {
            // Warm colors → happy, excited
            emotionProbs[.happy] = (emotionProbs[.happy] ?? 0) + warmBins * 0.4
            emotionProbs[.excited] = (emotionProbs[.excited] ?? 0) + warmBins * 0.2
        }
        if coolBins > 0.3 {
            // Cool colors → calm, sad
            emotionProbs[.calm] = (emotionProbs[.calm] ?? 0) + coolBins * 0.35
            emotionProbs[.sad] = (emotionProbs[.sad] ?? 0) + coolBins * 0.15
        }
        if greenBins > 0.2 {
            // Green → calm, hopeful
            emotionProbs[.calm] = (emotionProbs[.calm] ?? 0) + greenBins * 0.3
            emotionProbs[.hopeful] = (emotionProbs[.hopeful] ?? 0) + greenBins * 0.2
        }
        if meanSat < 0.15 {
            // Desaturated → neutral, reflective, sad
            emotionProbs[.neutral] = (emotionProbs[.neutral] ?? 0) + 0.25
            emotionProbs[.reflective] = (emotionProbs[.reflective] ?? 0) + 0.15
            emotionProbs[.sad] = (emotionProbs[.sad] ?? 0) + 0.1
        }

        // High contrast (bright + dark) → stressed, anxious
        if meanBri > 0.4 && meanSat > 0.5 && (hueHist[0] > 0.2) {
            emotionProbs[.stressed] = (emotionProbs[.stressed] ?? 0) + 0.2
            emotionProbs[.frustrated] = (emotionProbs[.frustrated] ?? 0) + 0.15
        }

        let colorDist = EmotionDistribution.from(emotionProbs)

        return ColorResult(
            hueHistogram: hueHist,
            meanSaturation: meanSat,
            meanBrightness: meanBri,
            emotionDist: colorDist
        )
    }

    // MARK: - Compute Final Signal

    private func computeSignal(
        scenes: [(label: String, prob: Float)],
        faces: [FaceResult],
        color: ColorResult
    ) -> ModalitySignal {

        // ─── 1. Scene → EmotionDistribution ───
        var sceneDist = EmotionDistribution.uniform
        var matchedAny = false

        for (label, prob) in scenes {
            let words = label.lowercased().split(separator: "_").map(String.init)
            for word in words {
                if let emotionMap = Self.sceneEmotions[word] {
                    matchedAny = true
                    let scaled = emotionMap.mapValues { $0 * Double(prob) }
                    let wordDist = EmotionDistribution.from(scaled)
                    sceneDist = sceneDist.merged(with: wordDist, weight: Double(prob))
                }
            }
        }

        // ─── 2. Face → EmotionDistribution ───
        var faceDist = EmotionDistribution.uniform
        let hasFaces = !faces.isEmpty

        if hasFaces {
            let avgSmile = faces.map(\.smileProbability).reduce(0, +) / Double(faces.count)
            let avgFrown = faces.map(\.frownProbability).reduce(0, +) / Double(faces.count)

            var faceEmotions: [Sentiment: Double] = [:]
            if avgSmile > 0.5 {
                faceEmotions[.happy] = avgSmile * 0.5
                faceEmotions[.excited] = avgSmile * 0.2
                faceEmotions[.grateful] = avgSmile * 0.1
            } else if avgFrown > 0.3 {
                faceEmotions[.sad] = avgFrown * 0.4
                faceEmotions[.frustrated] = avgFrown * 0.2
                faceEmotions[.anxious] = avgFrown * 0.1
            } else {
                faceEmotions[.neutral] = 0.3
                faceEmotions[.calm] = 0.2
                faceEmotions[.reflective] = 0.15
            }
            faceDist = EmotionDistribution.from(faceEmotions)
        }

        // ─── 3. Merge: scene + face + color ───
        // Weights: face = 0.4, scene = 0.35, color = 0.25
        var finalDist = faceDist
        if matchedAny {
            finalDist = finalDist.merged(with: sceneDist, weight: 0.85)
        }
        finalDist = finalDist.merged(with: color.emotionDist, weight: 0.6)

        // ─── 4. Confidence ───
        let topSceneProb = scenes.first.map { Double($0.prob) } ?? 0
        let faceContrib = hasFaces ? 0.25 : 0.0
        let sceneContrib = matchedAny ? min(0.4, topSceneProb) : 0.0
        let colorContrib = 0.15
        let confidence = min(0.85, faceContrib + sceneContrib + colorContrib)
        let adjustedConfidence = !matchedAny && !hasFaces ? 0.08 : confidence

        let uncertainty = max(0.15, 0.65 - adjustedConfidence * 0.5)

        // ─── 5. Feature labels ───
        var labels: [String] = []
        var features: [Double] = []

        let topEmotions = finalDist.topK(2)
        for e in topEmotions {
            labels.append(e.emotion.displayName.lowercased())
            features.append(e.probability)
        }

        if hasFaces {
            let avgSmile = faces.map(\.smileProbability).reduce(0, +) / Double(faces.count)
            labels.append(avgSmile > 0.5 ? "smiling faces" : "neutral faces")
            features.append(avgSmile)
        }
        if color.meanBrightness > 0.6 {
            labels.append("bright tones")
            features.append(color.meanBrightness)
        } else if color.meanBrightness < 0.3 {
            labels.append("dark tones")
            features.append(color.meanBrightness)
        }

        return ModalitySignal.make(
            modality: .image,
            valence: finalDist.valence,
            arousal: finalDist.arousal,
            confidence: adjustedConfidence,
            uncertainty: uncertainty,
            emotionDistribution: finalDist,
            featureVector: features,
            featureLabels: labels
        )
    }
}
