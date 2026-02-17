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
    var collage: CollageData?
    var sentiment: Sentiment?

    init(id: UUID = UUID(), title: String = "", content: String = "", date: Date = Date(), collage: CollageData? = nil, sentiment: Sentiment? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.collage = collage
        self.sentiment = sentiment
    }
}
