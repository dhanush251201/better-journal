//
//  EntryEditorView.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//
//  Unified note editor — single scrollable layout combining
//  text, photos, and drawing. No tabs.
//

import SwiftUI
import PencilKit
import PhotosUI

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

    // UI state
    @State private var showDrawingCanvas = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var contentFocused: Bool

    // Live mood — uses EmotionDistribution (same algorithm as stored mood)
    @State private var liveEmotion: Sentiment?
    @State private var liveValence: Double = 0
    @State private var liveArousal: Double = 0.35
    @State private var hasMoodEstimate: Bool = false
    @State private var analysisTask: Task<Void, Never>?

    // Human-in-the-loop emotion picker
    @State private var showEmotionPicker = false
    @State private var emotionCandidates: [EmotionCandidate] = []
    @State private var savedEntryID: UUID?

    init(store: JournalStore, entry: JournalEntry? = nil) {
        self.store = store
        self.existingEntry = entry
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
        _collageData = State(initialValue: entry?.collage ?? CollageData())
        _drawingID = State(initialValue: entry?.drawingID)

        if let dID = entry?.drawingID,
           let loaded = DrawingStorageManager.shared.loadDrawing(id: dID) {
            _drawing = State(initialValue: loaded)
            _showDrawingCanvas = State(initialValue: true)
        } else {
            _drawing = State(initialValue: PKDrawing())
        }
    }

    private var isNewEntry: Bool { existingEntry == nil }

    /// Read the live entry from the store — reacts to store updates.
    private var storeEntry: JournalEntry? {
        guard let id = existingEntry?.id else { return nil }
        return store.entries.first(where: { $0.id == id })
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
                // Mood-reactive background — emotion-based, same algorithm everywhere
                if hasMoodEstimate, let live = liveEmotion {
                    MoodGradientBackground(emotion: live, arousal: liveArousal)
                } else {
                    MoodGradientBackground(emotion: storeEntry?.resolvedEmotion)
                }

                VStack(spacing: 0) {
                    // Scrollable content area
                    ScrollView {
                        VStack(spacing: BJDesign.Spacing.md) {
                            // Title
                            TextField("Title", text: $title)
                                .font(.title2.weight(.semibold))
                                .padding(.horizontal)
                                .padding(.top, BJDesign.Spacing.md)
                                .submitLabel(.next)
                                .onSubmit { contentFocused = true }

                            Divider()
                                .padding(.horizontal)

                            // Content
                            TextEditor(text: $content)
                                .font(.body)
                                .padding(.horizontal, 12)
                                .focused($contentFocused)
                                .frame(minHeight: 200)
                                .scrollContentBackground(.hidden)
                                .onChange(of: content) { _, _ in
                                    debounceMoodAnalysis()
                                }
                                .onChange(of: title) { _, _ in
                                    debounceMoodAnalysis()
                                }

                            // Photos (inline)
                            if !collageData.isEmpty {
                                inlinePhotosSection
                            }

                            // Drawing (inline, toggleable)
                            if showDrawingCanvas {
                                inlineDrawingSection
                            }

                            // Mood display — single source of truth
                            if let emotion = storeEntry?.resolvedEmotion ?? liveEmotion {
                                HStack {
                                    SentimentTagView(sentiment: emotion)
                                    Spacer()
                                    if let score = storeEntry?.moodScore {
                                        moodConfidenceView(score)
                                    }
                                }
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }

                            Spacer(minLength: 80)
                        }
                    }

                    // Attachment toolbar
                    attachmentToolbar
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    addPhoto(image)
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        addPhoto(image)
                    }
                    selectedPhotoItem = nil
                }
            }
            .sheet(isPresented: $showEmotionPicker) {
                emotionPickerSheet
            }
        }
    }

    // liveSentiment removed — liveEmotion @State is set directly from analyzeSignal()

    // MARK: - Inline Photos Section

    private var inlinePhotosSection: some View {
        VStack(spacing: 8) {
            CollageDisplayView(collageData: collageData, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: BJDesign.Radius.medium))
                .padding(.horizontal)

            // Remove photos button
            HStack {
                Spacer()
                Button {
                    withAnimation(BJAnimation.quickFade) {
                        // Delete all photos
                        PhotoStorageManager.shared.deleteImages(ids: collageData.photoIDs)
                        collageData = CollageData()
                    }
                    BJHaptic.warning()
                } label: {
                    Label("Remove Photos", systemImage: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .padding(.trailing)
            }
        }
    }

    // MARK: - Inline Drawing Section

    private var inlineDrawingSection: some View {
        VStack(spacing: 4) {
            DrawingEditorView(drawing: $drawing)
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: BJDesign.Radius.medium))
                .padding(.horizontal)

            HStack {
                Spacer()
                Button {
                    withAnimation(BJAnimation.quickFade) {
                        drawing = PKDrawing()
                        showDrawingCanvas = false
                    }
                    BJHaptic.warning()
                } label: {
                    Label("Remove Drawing", systemImage: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .padding(.trailing)
            }
        }
    }

    // MARK: - Attachment Toolbar

    private var attachmentToolbar: some View {
        HStack(spacing: 0) {
            // Camera
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                    BJHaptic.soft()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "camera.fill")
                            .font(.body)
                        Text("Camera")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }

            // Gallery
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: 3) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.body)
                    Text("Gallery")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Draw toggle
            Button {
                withAnimation(BJAnimation.springGentle) {
                    showDrawingCanvas.toggle()
                }
                BJHaptic.soft()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: showDrawingCanvas ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                        .font(.body)
                    Text("Draw")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
                .foregroundStyle(showDrawingCanvas ? .purple : .secondary)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal)
        .background(.ultraThinMaterial)
    }

    // MARK: - Mood Confidence View

    private func moodConfidenceView(_ score: MoodScore) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text("\(Int(score.overallConfidence * 100))% confidence")
                .font(.system(.caption2, design: .rounded))
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Emotion Picker Sheet (Human-in-the-Loop)

    private var emotionPickerSheet: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(.purple)
                Text("How are you feeling?")
                    .font(.title3.weight(.semibold))
                Text("We detected a few possible emotions. Tap the one that feels most accurate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Emotion candidates as tappable pills
            VStack(spacing: 12) {
                ForEach(emotionCandidates, id: \.emotion) { candidate in
                    if let sentiment = Sentiment(rawValue: candidate.emotion) {
                        Button {
                            if let entryID = savedEntryID {
                                store.confirmUserEmotion(for: entryID, emotion: sentiment)
                            }
                            showEmotionPicker = false
                            BJHaptic.success()
                        } label: {
                            HStack {
                                Image(systemName: sentiment.iconName)
                                    .font(.title3)
                                    .foregroundStyle(sentiment.color)
                                    .frame(width: 32)

                                Text(sentiment.displayName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                // Probability bar
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(sentiment.color.opacity(0.3))
                                        .frame(width: geo.size.width * candidate.probability)
                                }
                                .frame(width: 60, height: 8)

                                Text("\(Int(candidate.probability * 100))%")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(sentiment.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)

            // Skip button
            Button {
                showEmotionPicker = false
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Live Mood Analysis

    private func debounceMoodAnalysis() {
        analysisTask?.cancel()
        analysisTask = Task {
            // Wait 1.5 seconds after the user stops typing
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }

            let text = title + " " + content
            guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else { return }

            if let signal = await SentimentAnalyzer.analyzeSignal(title: title, content: content) {
                // Use the EmotionDistribution's dominant emotion —
                // same algorithm as stored mood, so preview matches final result.
                let emotion = signal.emotionDistribution.dominantEmotion
                await MainActor.run {
                    withAnimation(BJAnimation.moodTransition) {
                        liveEmotion = emotion
                        liveValence = signal.valence
                        liveArousal = signal.arousal
                        hasMoodEstimate = true
                    }
                }
            }
        }
    }

    // MARK: - Photo Helper

    private func addPhoto(_ image: UIImage) {
        let id = UUID()
        PhotoStorageManager.shared.save(image: image, id: id)
        PhotoStorageManager.shared.saveThumbnail(image: image, id: id)
        collageData.photoIDs.append(id)

        // Auto-adjust layout
        switch collageData.photoIDs.count {
        case 1: collageData.layout = .single
        case 2: collageData.layout = .sideBySide
        case 3: collageData.layout = .triLayout
        default: collageData.layout = .quadGrid
        }
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
            let entryID = UUID()
            let entry = JournalEntry(
                id: entryID,
                title: trimmedTitle,
                content: trimmedContent,
                collage: collage,
                drawingID: finalDrawingID
            )
            store.add(entry)
            savedEntryID = entryID
        }

        // Dismiss immediately — don't make the user wait
        dismiss()
    }
}
