//
//  SentimentAnalyzer.swift
//  better-journal
//
//  Text modality extractor.
//  Uses NLTagger for continuous valence + FoundationModels for
//  categorical classification. Outputs ModalitySignal.
//

import Foundation
import NaturalLanguage
import FoundationModels

struct SentimentAnalyzer {

    // MARK: - ModalitySignal Output

    /// Produce a calibration-ready ModalitySignal from text.
    /// Uses NLTagger (.sentimentScore) for continuous valence and
    /// FoundationModels for categorical classification (secondary).
    static func analyzeSignal(title: String, content: String) async -> ModalitySignal? {
        let text = (title + " " + content).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let wordCount = text.split(separator: " ").count

        // --- NLTagger: continuous sentiment score ---
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let range = text.startIndex..<text.endIndex

        var sentimentScores: [Double] = []
        tagger.enumerateTags(in: range, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag, let score = Double(tag.rawValue) {
                sentimentScores.append(score)
            }
            return true
        }

        // Average sentence-level scores for document valence
        let valence: Double
        if !sentimentScores.isEmpty {
            valence = sentimentScores.reduce(0, +) / Double(sentimentScores.count)
        } else {
            valence = 0
        }

        // --- Uncertainty: decreases with word count ---
        // σ = 1 / √(wordCount) clamped to [0.15, 0.6]
        let rawUncertainty = 1.0 / sqrt(Double(max(1, wordCount)))
        let uncertainty = max(0.15, min(0.6, rawUncertainty))

        // --- Confidence: based on sentiment score variance (lower variance = more confident) ---
        let scoreVariance: Double
        if sentimentScores.count > 1 {
            let mean = sentimentScores.reduce(0, +) / Double(sentimentScores.count)
            scoreVariance = sentimentScores.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(sentimentScores.count)
        } else {
            scoreVariance = 0.1
        }
        // Lower variance = higher confidence. Entropy proxy.
        let confidence = max(0.1, min(0.9, 1.0 - sqrt(scoreVariance)))

        // --- Arousal heuristic: based on punctuation density + word length variance ---
        let exclamations = Double(text.filter { $0 == "!" }.count)
        let questions = Double(text.filter { $0 == "?" }.count)
        let caps = Double(text.filter(\.isUppercase).count)
        let totalChars = max(1.0, Double(text.count))
        let punctDensity = (exclamations + questions) / totalChars * 100
        let capsDensity = caps / totalChars
        let arousal = min(1.0, max(0.1, 0.3 + punctDensity * 0.15 + capsDensity * 0.5))

        // Feature labels for explainability
        var features: [Double] = [valence, arousal, confidence, Double(wordCount)]
        var labels: [String] = ["valence", "arousal", "confidence", "word count"]

        if valence > 0.3 {
            labels.append("uplifting language")
            features.append(valence)
        } else if valence < -0.3 {
            labels.append("somber language")
            features.append(valence)
        }

        return ModalitySignal.make(
            modality: .text,
            valence: max(-1, min(1, valence)),
            arousal: arousal,
            confidence: confidence,
            uncertainty: uncertainty,
            featureVector: features,
            featureLabels: labels
        )
    }

    // MARK: - Categorical (for backward compat display)

    /// Categorical sentiment via FoundationModels (used for UI label display only).
    static func analyze(title: String, content: String) async -> Sentiment? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        do {
            let session = LanguageModelSession()
            let prompt = "Analyze the sentiment of this journal entry and classify it into exactly one category. Title: \(title) Content: \(content)"
            let response = try await session.respond(to: prompt, generating: Sentiment.self)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Insight Generation

    static func generateInsight(from entries: [JournalEntry]) async -> String? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let summaries = entries.prefix(5).enumerated().map { index, entry in
            let sentiment = entry.sentiment?.displayName ?? "Unknown"
            let title = entry.title.isEmpty ? "Untitled" : entry.title
            let snippet = String(entry.content.prefix(200))
            return "Entry \(index + 1) (\(sentiment)): \"\(title)\" — \(snippet)"
        }

        let joined = summaries.joined(separator: "\n")
        let prompt = """
        You are a thoughtful journaling coach. Based on these recent journal entries, provide a single brief, \
        warm, and insightful observation (2 sentences max) about the person's emotional patterns or growth. \
        Be specific to what they wrote — don't be generic. Speak directly to them using "you".

        \(joined)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }
}
