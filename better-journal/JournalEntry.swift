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

    // Metadata
    var wordCount: Int

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
