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

    private let storageKey = "journal_entries"

    init() {
        load()
    }

    func add(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func update(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = saved
    }
}
