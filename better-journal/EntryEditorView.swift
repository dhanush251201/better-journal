//
//  EntryEditorView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let store: JournalStore
    private let existingEntry: JournalEntry?

    @State private var title: String
    @State private var content: String
    @FocusState private var contentFocused: Bool

    init(store: JournalStore, entry: JournalEntry? = nil) {
        self.store = store
        self.existingEntry = entry
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
    }

    private var isNewEntry: Bool { existingEntry == nil }

    private var hasChanges: Bool {
        guard let existing = existingEntry else {
            return !title.isEmpty || !content.isEmpty
        }
        return title != existing.title || content != existing.content
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Title", text: $title)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .submitLabel(.next)
                    .onSubmit { contentFocused = true }

                Divider()
                    .padding(.horizontal)

                TextEditor(text: $content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .focused($contentFocused)
            }
            .navigationTitle(isNewEntry ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isNewEntry {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasChanges)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingEntry {
            var updated = existing
            updated.title = trimmedTitle
            updated.content = trimmedContent
            updated.date = Date()
            store.update(updated)
        } else {
            let entry = JournalEntry(title: trimmedTitle, content: trimmedContent)
            store.add(entry)
            dismiss()
        }
    }
}
