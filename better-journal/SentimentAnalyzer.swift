//
//  SentimentAnalyzer.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/17/26.
//

import Foundation
import FoundationModels

struct SentimentAnalyzer {
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
