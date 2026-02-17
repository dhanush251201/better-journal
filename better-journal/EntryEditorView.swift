//
//  EntryEditorView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import SwiftUI
import PhotosUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let store: JournalStore
    private let existingEntry: JournalEntry?

    @State private var title: String
    @State private var content: String
    @State private var collageData: CollageData
    @FocusState private var contentFocused: Bool

    init(store: JournalStore, entry: JournalEntry? = nil) {
        self.store = store
        self.existingEntry = entry
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
        _collageData = State(initialValue: entry?.collage ?? CollageData())
    }

    private var isNewEntry: Bool { existingEntry == nil }

    private var currentSentiment: Sentiment? {
        guard let id = existingEntry?.id else { return nil }
        return store.entries.first(where: { $0.id == id })?.sentiment
    }

    private var hasChanges: Bool {
        guard let existing = existingEntry else {
            return !title.isEmpty || !content.isEmpty || !collageData.isEmpty
        }
        return title != existing.title
            || content != existing.content
            || collageData != (existing.collage ?? CollageData())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    CollageEditorView(collageData: $collageData)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    TextField("Title", text: $title)
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .submitLabel(.next)
                        .onSubmit { contentFocused = true }

                    Divider()
                        .padding(.horizontal)

                    TextEditor(text: $content)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .focused($contentFocused)
                        .frame(minHeight: 300)

                    if let sentiment = currentSentiment {
                        HStack {
                            SentimentTagView(sentiment: sentiment)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
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

        let collage: CollageData? = collageData.isEmpty ? nil : collageData

        if let existing = existingEntry {
            var updated = existing
            updated.title = trimmedTitle
            updated.content = trimmedContent
            updated.date = Date()
            updated.collage = collage
            store.update(updated)
        } else {
            let entry = JournalEntry(title: trimmedTitle, content: trimmedContent, collage: collage)
            store.add(entry)
            dismiss()
        }
    }
}
