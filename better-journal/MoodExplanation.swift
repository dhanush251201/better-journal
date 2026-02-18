//
//  MoodExplanation.swift
//  better-journal
//
//  Generates natural-language explanations from modality contributions.
//  Never reveals raw valence/arousal numbers.
//  Always qualifies with hedging language.
//

import Foundation

// MARK: - Mood Explanation

struct MoodExplanation: Codable, Sendable, Equatable {
    /// One-sentence summary shown to the user.
    let summary: String
    /// Per-modality directional descriptions.
    let contributions: [ExplanationContribution]
    /// Confidence qualifier.
    let confidenceStatement: String
}

struct ExplanationContribution: Codable, Sendable, Equatable {
    let modality: ModalityType
    let influence: Double     // [0, 1]
    let direction: String     // "positive", "negative", "neutral"
    let description: String   // e.g. "uplifting language in your writing"
}

// MARK: - Explainer

struct MoodExplainer {

    /// Generate a human-friendly explanation from a calibrated mood score.
    static func explain(_ score: MoodScore) -> MoodExplanation {
        let sorted = score.contributions.sorted { $0.influence > $1.influence }
        let total = sorted.map(\.influence).reduce(0, +)

        var parts: [ExplanationContribution] = []
        var summaryFragments: [String] = []

        for contribution in sorted.prefix(2) where contribution.influence > 0.15 {
            let direction = directionLabel(valence: contribution.valence)
            let description = describeModality(contribution)
            let pct = total > 0 ? contribution.influence / total : 0

            parts.append(ExplanationContribution(
                modality: contribution.modality,
                influence: pct,
                direction: direction,
                description: description
            ))
            summaryFragments.append(description)
        }

        // Build summary sentence
        let moodWord = moodDirection(score.valence)
        let summary: String
        if summaryFragments.isEmpty {
            summary = "Not enough signal to determine a clear mood direction."
        } else if summaryFragments.count == 1 {
            summary = "Your mood \(moodWord), primarily due to \(summaryFragments[0])."
        } else {
            summary = "Your mood \(moodWord), influenced by \(summaryFragments[0]) and \(summaryFragments[1])."
        }

        // Confidence qualifier
        let confStatement: String
        if score.overallConfidence > 0.7 {
            confStatement = "This assessment has strong confidence."
        } else if score.overallConfidence > 0.4 {
            confStatement = "This is a moderate confidence estimate."
        } else {
            confStatement = "This is a tentative reading — more signals would improve accuracy."
        }

        return MoodExplanation(
            summary: summary,
            contributions: parts,
            confidenceStatement: confStatement
        )
    }

    // MARK: - Private Helpers

    private static func directionLabel(valence: Double) -> String {
        if valence > 0.2 { return "positive" }
        if valence < -0.2 { return "negative" }
        return "neutral"
    }

    private static func moodDirection(_ valence: Double) -> String {
        if valence > 0.4 { return "leaned positive" }
        if valence > 0.1 { return "leaned slightly positive" }
        if valence > -0.1 { return "stayed balanced" }
        if valence > -0.4 { return "leaned slightly low" }
        return "leaned low"
    }

    private static func describeModality(_ c: ModalityContribution) -> String {
        let featureStr = c.keyFeatures.prefix(2).joined(separator: " and ")

        switch c.modality {
        case .text:
            if featureStr.isEmpty {
                return c.valence > 0
                    ? "uplifting language in your writing"
                    : "somber language in your writing"
            }
            return featureStr + " in your writing"

        case .image:
            if featureStr.isEmpty {
                return c.valence > 0
                    ? "warm tones in your photos"
                    : "muted tones in your photos"
            }
            return featureStr + " in your photos"

        case .drawing:
            if featureStr.isEmpty {
                return c.valence > 0
                    ? "expressive strokes in your drawing"
                    : "restrained strokes in your drawing"
            }
            return featureStr + " in your drawing"
        }
    }
}
