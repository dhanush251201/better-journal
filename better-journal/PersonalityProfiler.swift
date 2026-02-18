//
//  PersonalityProfiler.swift
//  better-journal
//
//  Derives long-term personality traits from accumulated MoodSummary data.
//  All computation on-device. Never exported.
//
//  New traits: emotional stability, optimism bias, negative affect bias,
//  reactivity, recovery rate — all statistically derived.
//

import Foundation

actor PersonalityProfiler {

    /// Update (or create) a PersonalityProfile from daily summaries.
    func updateProfile(
        from summaries: [MoodSummary],
        entries: [JournalEntry],
        existing: PersonalityProfile?
    ) -> PersonalityProfile {
        guard !summaries.isEmpty else { return existing ?? .empty }

        // --- Emotional Baseline ---
        let valences = summaries.map(\.averageValence)
        let arousals = summaries.map(\.averageArousal)
        let baselineValence = valences.reduce(0, +) / Double(valences.count)
        let baselineArousal = arousals.reduce(0, +) / Double(arousals.count)

        // --- Volatility (sample std deviation of daily valence) ---
        let volatility = standardDeviation(valences)

        // --- Emotional Stability = 1 - σ_valence (clamped [0, 1]) ---
        let stability = max(0, min(1, 1.0 - volatility))

        // --- Optimism Bias = mean valence ---
        let optimism = baselineValence

        // --- Negative Affect Bias = fraction of days below -0.3 ---
        let negDays = valences.filter { $0 < -0.3 }.count
        let negBias = Double(negDays) / Double(valences.count)

        // --- Reactivity = mean |Δv| between consecutive days ---
        var reactivity = 0.0
        if valences.count > 1 {
            var totalDelta = 0.0
            for i in 1..<valences.count {
                totalDelta += abs(valences[i] - valences[i - 1])
            }
            reactivity = totalDelta / Double(valences.count - 1)
        }

        // --- Recovery Rate ---
        // Find dips (below baseline - 0.3 std), then measure the slope
        // of valence increase in the 3-day window after the dip.
        let threshold = baselineValence - max(0.1, volatility * 0.5)
        var recoverySlopes: [Double] = []
        for i in 0..<valences.count {
            if valences[i] < threshold {
                // Look at next 1–3 days
                let window = min(3, valences.count - i - 1)
                if window > 0 {
                    let slope = (valences[i + window] - valences[i]) / Double(window)
                    recoverySlopes.append(slope)
                }
            }
        }
        let recoveryRate = recoverySlopes.isEmpty ? 0 : recoverySlopes.reduce(0, +) / Double(recoverySlopes.count)

        // --- Dominant Traits ---
        let traitCounts = summaries.reduce(into: [String: Int]()) { counts, summary in
            counts[summary.dominantSentiment, default: 0] += 1
        }
        let dominantTraits = traitCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)

        // --- Time Patterns ---
        let timePatterns = computeTimePatterns(from: entries)

        // --- Seasonal Trends ---
        let seasonalTrends = computeSeasonalTrends(from: summaries)

        // --- Recurring Themes ---
        let themes = extractThemes(from: entries)

        return PersonalityProfile(
            baselineValence: baselineValence,
            baselineArousal: baselineArousal,
            volatilityIndex: volatility,
            emotionalStability: stability,
            optimismBias: optimism,
            negativeAffectBias: negBias,
            reactivityScore: reactivity,
            recoveryRate: recoveryRate,
            dominantTraits: Array(dominantTraits),
            timePatterns: timePatterns,
            seasonalTrends: seasonalTrends,
            recurringThemes: themes,
            lastUpdated: Date(),
            dataPointCount: summaries.count
        )
    }

    // MARK: - Time Patterns

    private func computeTimePatterns(from entries: [JournalEntry]) -> [TimePattern] {
        let calendar = Calendar.current
        var buckets: [Int: (valenceSum: Double, arousalSum: Double, count: Int)] = [:]

        for entry in entries {
            guard let score = entry.moodScore else { continue }
            let hour = calendar.component(.hour, from: entry.date)
            var bucket = buckets[hour, default: (0, 0, 0)]
            bucket.valenceSum += score.valence
            bucket.arousalSum += score.arousal
            bucket.count += 1
            buckets[hour] = bucket
        }

        return buckets.map { hour, data in
            TimePattern(
                hourBucket: hour,
                averageValence: data.valenceSum / Double(data.count),
                averageArousal: data.arousalSum / Double(data.count),
                sampleCount: data.count
            )
        }.sorted { $0.hourBucket < $1.hourBucket }
    }

    // MARK: - Seasonal Trends

    private func computeSeasonalTrends(from summaries: [MoodSummary]) -> [SeasonalTrend] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        var buckets: [Int: (valenceSum: Double, arousalSum: Double, count: Int)] = [:]

        for summary in summaries {
            guard let date = formatter.date(from: summary.dateKey) else { continue }
            let month = calendar.component(.month, from: date)
            var bucket = buckets[month, default: (0, 0, 0)]
            bucket.valenceSum += summary.averageValence
            bucket.arousalSum += summary.averageArousal
            bucket.count += 1
            buckets[month] = bucket
        }

        return buckets.map { month, data in
            SeasonalTrend(
                month: month,
                averageValence: data.valenceSum / Double(data.count),
                averageArousal: data.arousalSum / Double(data.count),
                sampleCount: data.count
            )
        }.sorted { $0.month < $1.month }
    }

    // MARK: - Theme Extraction

    private func extractThemes(from entries: [JournalEntry]) -> [String] {
        let stopWords: Set<String> = [
            "the", "a", "an", "is", "was", "were", "are", "been", "be", "have", "has",
            "had", "do", "does", "did", "will", "would", "could", "should", "may",
            "might", "shall", "can", "need", "must", "i", "me", "my", "we", "our",
            "you", "your", "he", "she", "it", "they", "them", "this", "that", "these",
            "those", "and", "but", "or", "nor", "not", "so", "yet", "to", "of", "in",
            "for", "on", "with", "at", "by", "from", "as", "into", "about", "like",
            "just", "very", "really", "also", "too", "than", "then", "its", "what",
            "when", "where", "how", "all", "each", "every", "both", "few", "more",
            "some", "such", "no", "only", "same", "other", "new", "old", "one", "two",
        ]

        var wordCounts: [String: Int] = [:]

        for entry in entries {
            let words = (entry.title + " " + entry.content)
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 && !stopWords.contains($0) }

            for word in words {
                wordCounts[word, default: 0] += 1
            }
        }

        return wordCounts
            .filter { $0.value >= 3 }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map(\.key)
    }

    // MARK: - Math Helpers

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
}
