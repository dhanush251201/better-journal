//
//  MoodSummary.swift
//  better-journal
//
//  Daily mood aggregation — one summary per calendar day.
//  Powers weekly insights, personality profiling, and trend visualization.
//

import Foundation

struct MoodSummary: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var dateKey: String              // "2026-02-17" (ISO local date)
    var averageValence: Double
    var averageArousal: Double
    /// Fused uncertainty of the day's mood estimate.
    var averageUncertainty: Double
    /// Z-score relative to user baseline (nil if baseline not yet active).
    var baselineZScore: Double?
    var dominantSentiment: String    // Sentiment rawValue
    var entryCount: Int
    var entryIDs: [UUID]
    var computedAt: Date

    init(
        id: UUID = UUID(),
        dateKey: String,
        averageValence: Double,
        averageArousal: Double,
        averageUncertainty: Double = 0.5,
        baselineZScore: Double? = nil,
        dominantSentiment: String,
        entryCount: Int,
        entryIDs: [UUID],
        computedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.averageValence = averageValence
        self.averageArousal = averageArousal
        self.averageUncertainty = averageUncertainty
        self.baselineZScore = baselineZScore
        self.dominantSentiment = dominantSentiment
        self.entryCount = entryCount
        self.entryIDs = entryIDs
        self.computedAt = computedAt
    }

    /// Short day label for use in charts ("Mon", "Tue", …)
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return "" }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
}
