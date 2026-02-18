//
//  EntryEditorView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//

import SwiftUI
import PencilKit
import PhotosUI

// MARK: - Editor Mode

enum EditorMode: String, CaseIterable {
    case write = "Write"
    case draw = "Draw"
    case media = "Media"

    var icon: String {
        switch self {
        case .write: return "text.cursor"
        case .draw:  return "pencil.tip"
        case .media: return "photo.on.rectangle"
        }
    }
}

// MARK: - Entry Editor

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let store: JournalStore
    private let existingEntry: JournalEntry?

    @State private var title: String
    @State private var content: String
    @State private var collageData: CollageData
    @State private var drawing: PKDrawing
    @State private var drawingID: UUID?
    @State private var editorMode: EditorMode = .write
    @FocusState private var contentFocused: Bool

    init(store: JournalStore, entry: JournalEntry? = nil) {
        self.store = store
        self.existingEntry = entry
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
        _collageData = State(initialValue: entry?.collage ?? CollageData())
        _drawingID = State(initialValue: entry?.drawingID)

        // Load existing drawing if present
        if let dID = entry?.drawingID,
           let loaded = DrawingStorageManager.shared.loadDrawing(id: dID) {
            _drawing = State(initialValue: loaded)
        } else {
            _drawing = State(initialValue: PKDrawing())
        }
    }

    private var isNewEntry: Bool { existingEntry == nil }

    private var currentSentiment: Sentiment? {
        guard let id = existingEntry?.id else { return nil }
        return store.entries.first(where: { $0.id == id })?.sentiment
    }

    private var currentMoodScore: MoodScore? {
        guard let id = existingEntry?.id else { return nil }
        return store.entries.first(where: { $0.id == id })?.moodScore
    }

    private var hasChanges: Bool {
        guard let existing = existingEntry else {
            return !title.isEmpty || !content.isEmpty
                || !collageData.isEmpty || !drawing.strokes.isEmpty
        }
        return title != existing.title
            || content != existing.content
            || collageData != (existing.collage ?? CollageData())
            || !drawing.strokes.isEmpty != (existing.drawingID != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Mood gradient background
                MoodGradientBackground(moodScore: currentMoodScore)

                VStack(spacing: 0) {
                    // Mode selector
                    modePicker
                        .padding(.top, BJDesign.Spacing.sm)
                        .padding(.bottom, BJDesign.Spacing.md)

                    // Content area
                    ScrollView {
                        VStack(spacing: 0) {
                            switch editorMode {
                            case .write:
                                writeMode

                            case .draw:
                                drawMode

                            case .media:
                                mediaMode
                            }

                            // Mood display
                            if let sentiment = currentSentiment {
                                HStack {
                                    SentimentTagView(sentiment: sentiment)
                                    Spacer()
                                    if let score = currentMoodScore {
                                        moodConfidenceView(score)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, BJDesign.Spacing.md)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
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

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(EditorMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(BJAnimation.quickFade) {
                        editorMode = mode
                    }
                    BJHaptic.selection()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.body)
                        Text(mode.rawValue)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(editorMode == mode ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BJDesign.Spacing.sm)
                    .background {
                        if editorMode == mode {
                            RoundedRectangle(cornerRadius: BJDesign.Radius.small)
                                .fill(.ultraThinMaterial)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, BJDesign.Spacing.lg)
    }

    // MARK: - Write Mode

    private var writeMode: some View {
        VStack(spacing: 0) {
            // Photo strip preview (if photos exist)
            if !collageData.isEmpty {
                CollageDisplayView(collageData: collageData, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: BJDesign.Radius.small))
                    .padding(.horizontal)
                    .padding(.bottom, BJDesign.Spacing.md)
            }

            // Drawing preview (if drawing exists)
            if !drawing.strokes.isEmpty, let dID = drawingID {
                DrawingThumbnailView(drawingID: dID, height: 60)
                    .padding(.horizontal)
                    .padding(.bottom, BJDesign.Spacing.md)
            }

            TextField("Title", text: $title)
                .font(.title2.weight(.semibold))
                .padding(.horizontal)
                .padding(.bottom, BJDesign.Spacing.sm)
                .submitLabel(.next)
                .onSubmit { contentFocused = true }

            Divider()
                .padding(.horizontal)

            TextEditor(text: $content)
                .font(.body)
                .padding(.horizontal, 12)
                .focused($contentFocused)
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Draw Mode

    private var drawMode: some View {
        DrawingEditorView(drawing: $drawing)
            .frame(minHeight: 400)
    }

    // MARK: - Media Mode

    private var mediaMode: some View {
        VStack(spacing: BJDesign.Spacing.md) {
            CollageEditorView(collageData: $collageData)
                .padding(.top, BJDesign.Spacing.sm)
        }
    }

    // MARK: - Mood Confidence

    private func moodConfidenceView(_ score: MoodScore) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text("\(Int(score.overallConfidence * 100))% confidence")
                .font(.system(.caption2, design: .rounded))
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Save

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        let collage: CollageData? = collageData.isEmpty ? nil : collageData

        // Save drawing if present
        var finalDrawingID: UUID? = drawingID
        if !drawing.strokes.isEmpty {
            let dID = finalDrawingID ?? UUID()
            DrawingStorageManager.shared.save(drawing: drawing, id: dID)
            DrawingStorageManager.shared.saveThumbnail(drawing: drawing, id: dID)
            finalDrawingID = dID
        } else if drawing.strokes.isEmpty && finalDrawingID != nil {
            // Drawing was cleared
            DrawingStorageManager.shared.delete(id: finalDrawingID!)
            finalDrawingID = nil
        }

        if let existing = existingEntry {
            var updated = existing
            updated.title = trimmedTitle
            updated.content = trimmedContent
            updated.date = Date()
            updated.collage = collage
            updated.drawingID = finalDrawingID
            updated.wordCount = trimmedContent.split(separator: " ").count
            store.update(updated)
        } else {
            let entry = JournalEntry(
                title: trimmedTitle,
                content: trimmedContent,
                collage: collage,
                drawingID: finalDrawingID
            )
            store.add(entry)
            dismiss()
        }
    }
}
