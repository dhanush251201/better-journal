//
//  JournalStore.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import Foundation
import Observation
import SwiftUI

@Observable
class JournalStore {
    var entries: [JournalEntry] = []
    var journalInsight: String?

    private let storageKey = "journal_entries"

    init() {
        load()
        refreshInsight()
    }

    func add(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        save()
        analyzeSentiment(for: entry.id)
    }

    func update(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            // Delete orphaned photos
            let oldIDs = entries[index].collage?.photoIDs ?? []
            let newIDs = Set(entry.collage?.photoIDs ?? [])
            let orphaned = oldIDs.filter { !newIDs.contains($0) }
            PhotoStorageManager.shared.deleteImages(ids: orphaned)

            var updated = entry
            updated.sentiment = nil
            entries[index] = updated
            save()
            analyzeSentiment(for: entry.id)
        }
    }

    private func analyzeSentiment(for entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              !entry.title.isEmpty || !entry.content.isEmpty else { return }

        Task {
            guard let sentiment = await SentimentAnalyzer.analyze(title: entry.title, content: entry.content) else { return }
            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == entryID }) {
                    entries[index].sentiment = sentiment
                    save()
                    refreshInsight()
                }
            }
        }
    }

    func refreshInsight() {
        guard entries.count >= 5 else {
            journalInsight = nil
            return
        }

        Task {
            guard let insight = await SentimentAnalyzer.generateInsight(from: Array(entries.prefix(5))) else { return }
            await MainActor.run {
                journalInsight = insight
            }
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            if let photoIDs = entries[index].collage?.photoIDs {
                PhotoStorageManager.shared.deleteImages(ids: photoIDs)
            }
        }
        entries.remove(atOffsets: offsets)
        save()
        refreshInsight()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

        guard !entryDays.isEmpty else { return 0 }

        // Start from today or yesterday
        var checkDate = today
        if !entryDays.contains(today) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
            if !entryDays.contains(checkDate) { return 0 }
        }

        var streak = 0
        while entryDays.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        guard !entryDays.isEmpty else { return 0 }

        let sorted = entryDays.sorted()
        var longest = 1
        var current = 1

        for i in 1..<sorted.count {
            let diff = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = saved
    }
}
