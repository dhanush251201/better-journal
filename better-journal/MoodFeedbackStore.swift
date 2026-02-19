//
//  MoodFeedbackStore.swift
//  better-journal
//
//  Human-in-the-loop feedback storage.
//  Learns from user corrections to bias future predictions.
//
//  Stores a dictionary: keyword → { emotion: correction_count }
//  When the user corrects a mood, we extract keywords from the entry
//  and record which mood they associated with those words.
//

import Foundation

// MARK: - Mood Feedback Store

final class MoodFeedbackStore {
    static let shared = MoodFeedbackStore()

    private let storageKey = "mood_feedback_keywords"

    /// keyword → [Sentiment.rawValue : count]
    private var keywordMoods: [String: [String: Int]]

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            keywordMoods = decoded
        } else {
            keywordMoods = [:]
        }
    }

    // MARK: - Record Correction

    /// Called when the user corrects a mood. Extracts significant words
    /// and increments their association with the corrected mood.
    func recordCorrection(text: String, correctedMood: Sentiment) {
        let words = extractKeywords(from: text)
        let moodKey = correctedMood.rawValue

        for word in words {
            keywordMoods[word, default: [:]][moodKey, default: 0] += 1
        }

        save()
    }

    // MARK: - Bias Distribution

    /// Adjusts an EmotionDistribution based on learned user patterns.
    /// Returns the adjusted distribution (or original if no relevant data).
    func biasDistribution(_ dist: EmotionDistribution, forText text: String) -> EmotionDistribution {
        let words = extractKeywords(from: text)
        guard !words.isEmpty else { return dist }

        var biasAccum: [Sentiment: Double] = [:]
        var matchCount = 0

        for word in words {
            guard let moods = keywordMoods[word] else { continue }
            matchCount += 1
            for (moodRaw, count) in moods {
                if let mood = Sentiment(rawValue: moodRaw) {
                    biasAccum[mood, default: 0] += Double(count)
                }
            }
        }

        // Only bias if we have at least 2 keyword matches
        guard matchCount >= 2, !biasAccum.isEmpty else { return dist }

        // Build a bias distribution
        let biasDist = EmotionDistribution.from(biasAccum)

        // Merge with 20% weight for user feedback (gentle nudge, not override)
        return dist.merged(with: biasDist, weight: 0.25)
    }

    // MARK: - Helpers

    /// Extract significant words (lowercase, 4+ chars, not stopwords)
    private func extractKeywords(from text: String) -> [String] {
        let stopwords: Set<String> = [
            "that", "this", "with", "from", "have", "been", "were", "they",
            "them", "their", "what", "when", "where", "which", "while",
            "about", "after", "before", "could", "would", "should", "there",
            "these", "those", "then", "than", "some", "only", "just",
            "also", "more", "most", "very", "really", "much", "many",
            "does", "doing", "done", "will", "into", "over", "such",
            "being", "other", "each", "every", "like", "make", "made",
            "know", "think", "feel", "want", "need", "going", "come",
            "came", "take", "took", "give", "gave", "said", "tell",
            "told", "work", "well", "back", "even", "still", "here"
        ]

        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stopwords.contains($0) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(keywordMoods) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
