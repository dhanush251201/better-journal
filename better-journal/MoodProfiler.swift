//
//  MoodProfiler.swift
//  better-journal
//
//  Builds daily MoodSummary records with uncertainty-weighted
//  averaging from calibrated mood scores.
//

import Foundation

actor MoodProfiler {

    /// Compute the MoodSummary for a given calendar day.
    /// Uses uncertainty-weighted averaging instead of naive mean.
    func summarize(entries: [JournalEntry], for dateKey: String) -> MoodSummary? {
        let dayEntries = entries.filter { entryDateKey($0.date) == dateKey }
        guard !dayEntries.isEmpty else { return nil }

        let scores = dayEntries.compactMap(\.moodScore)
        guard !scores.isEmpty else { return nil }

        // Uncertainty-weighted averaging: weight each entry by 1/σ²
        var totalPrecision = 0.0
        var weightedValence = 0.0
        var weightedArousal = 0.0

        for score in scores {
            let precision = 1.0 / max(0.01, score.valenceUncertainty * score.valenceUncertainty)
            weightedValence += score.valence * precision
            weightedArousal += score.arousal * precision
            totalPrecision += precision
        }

        let avgValence = totalPrecision > 0 ? weightedValence / totalPrecision : 0
        let avgArousal = totalPrecision > 0 ? weightedArousal / totalPrecision : 0.35
        let avgUncertainty = totalPrecision > 0 ? 1.0 / sqrt(totalPrecision) : 0.5

        // Average baseline z-score (if available)
        let zScores = scores.compactMap(\.baselineZScore)
        let avgZScore: Double? = zScores.isEmpty ? nil : zScores.reduce(0, +) / Double(zScores.count)

        // Dominant sentiment: most frequent
        let sentimentCounts = scores.reduce(into: [String: Int]()) { counts, score in
            counts[score.primarySentiment, default: 0] += 1
        }
        let dominant = sentimentCounts.max(by: { $0.value < $1.value })?.key ?? Sentiment.neutral.rawValue

        return MoodSummary(
            dateKey: dateKey,
            averageValence: avgValence,
            averageArousal: avgArousal,
            averageUncertainty: avgUncertainty,
            baselineZScore: avgZScore,
            dominantSentiment: dominant,
            entryCount: dayEntries.count,
            entryIDs: dayEntries.map(\.id)
        )
    }

    /// Build summaries for the last N days.
    func buildRecentSummaries(entries: [JournalEntry], days: Int = 30) -> [MoodSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var summaries: [MoodSummary] = []
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let key = entryDateKey(date)
            if let summary = summarize(entries: entries, for: key) {
                summaries.append(summary)
            }
        }

        return summaries.reversed() // oldest first
    }

    // MARK: - Helpers

    private func entryDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
