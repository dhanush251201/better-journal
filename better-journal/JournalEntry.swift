//
//  JournalEntry.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import Foundation

struct JournalEntry: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var date: Date

    // Media: photo collage (existing)
    var collage: CollageData?

    // Media: drawing
    var drawingID: UUID?

    // Mood: original text sentiment (backward compat)
    var sentiment: Sentiment?

    // Mood: fused multi-modal mood score
    var moodScore: MoodScore?

    // Mood: user-confirmed emotion (human-in-the-loop)
    var userEmotion: Sentiment?

    // Metadata
    var wordCount: Int

    // MARK: - Single Source of Truth

    /// The canonical mood for this entry. Every view should read this.
    /// Priority: user-confirmed > distribution dominant > legacy sentiment > nil
    var resolvedEmotion: Sentiment? {
        if let userEmotion { return userEmotion }
        if let label = moodScore?.bestEmotionLabel,
           let s = Sentiment(rawValue: label) { return s }
        return sentiment
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        date: Date = Date(),
        collage: CollageData? = nil,
        drawingID: UUID? = nil,
        sentiment: Sentiment? = nil,
        moodScore: MoodScore? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.collage = collage
        self.drawingID = drawingID
        self.sentiment = sentiment
        self.moodScore = moodScore
        self.wordCount = content.split(separator: " ").count
    }
}
