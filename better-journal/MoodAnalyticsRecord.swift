//
//  MoodAnalyticsRecord.swift
//  better-journal
//
//  SwiftData model for the siloed analytics layer.
//  Contains mood metadata ONLY — never journal text.
//  Denormalized time columns enable zero-Calendar aggregation queries.
//

import Foundation
import SwiftData

@Model
final class MoodAnalyticsRecord {

    // MARK: - Identity

    /// Foreign key to the journal entry. One record per entry.
    @Attribute(.unique) var noteID: UUID

    // MARK: - Temporal (denormalized for fast GROUP BY)

    var timestamp: Date
    var hourOfDay: Int       // 0–23
    var dayOfWeek: Int       // 1 (Sun) – 7 (Sat)
    var monthOfYear: Int     // 1–12
    var yearValue: Int       // e.g. 2026

    // MARK: - Mood Metadata

    /// Sentiment.rawValue — e.g. "happy", "calm", "anxious"
    var moodCategory: String

    /// Derived intensity: confidence × arousal mapped to 1–10
    var moodIntensity: Int

    /// Dimensional values from the fused MoodScore
    var valence: Double      // -1.0 … 1.0
    var arousal: Double      //  0.0 … 1.0

    /// Pipeline confidence & conflict flag
    var overallConfidence: Double
    var hadConflict: Bool

    // MARK: - Init

    init(
        noteID: UUID,
        timestamp: Date,
        moodCategory: String,
        moodIntensity: Int,
        valence: Double,
        arousal: Double,
        overallConfidence: Double,
        hadConflict: Bool
    ) {
        self.noteID = noteID
        self.timestamp = timestamp
        self.moodCategory = moodCategory
        self.moodIntensity = moodIntensity
        self.valence = valence
        self.arousal = arousal
        self.overallConfidence = overallConfidence
        self.hadConflict = hadConflict

        // Denormalize time components once at write time
        let cal = Calendar.current
        self.hourOfDay = cal.component(.hour, from: timestamp)
        self.dayOfWeek = cal.component(.weekday, from: timestamp)
        self.monthOfYear = cal.component(.month, from: timestamp)
        self.yearValue = cal.component(.year, from: timestamp)
    }
}

// MARK: - Factory

extension MoodAnalyticsRecord {

    /// Create an analytics record from a JournalEntry + its computed MoodScore.
    /// Never accesses entry.content or entry.title.
    static func from(entry: JournalEntry, moodScore: MoodScore) -> MoodAnalyticsRecord {
        let intensity = Self.computeIntensity(
            confidence: moodScore.overallConfidence,
            arousal: moodScore.arousal
        )

        return MoodAnalyticsRecord(
            noteID: entry.id,
            timestamp: entry.date,
            moodCategory: moodScore.bestEmotionLabel,
            moodIntensity: intensity,
            valence: moodScore.valence,
            arousal: moodScore.arousal,
            overallConfidence: moodScore.overallConfidence,
            hadConflict: moodScore.hadConflict
        )
    }

    /// Maps confidence × arousal to a 1–10 integer intensity.
    private static func computeIntensity(confidence: Double, arousal: Double) -> Int {
        let raw = (confidence * 0.4 + arousal * 0.6) * 10.0
        return max(1, min(10, Int(raw.rounded())))
    }
}
