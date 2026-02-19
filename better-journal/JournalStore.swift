//
//  JournalStore.swift
//  better-journal
//
//  Persists journal entries, mood engine state (Kalman / Baseline / Calibration),
//  mood summaries, and personality profiles. All data stored locally via UserDefaults.
//
//  ARCHITECTURAL INVARIANTS:
//    1. Mood lives in JournalEntry.moodScore — no separate sentiment path
//    2. update() never clears mood — old values stay visible until re-analysis completes
//    3. Only one analysis runs per entry at a time (analysisInFlight gate)
//    4. refreshInsight/refreshProfiles are debounced (5s), not per-save
//

import Foundation
import Observation
import PencilKit
import SwiftData
import SwiftUI

@Observable
class JournalStore {
    var entries: [JournalEntry] = []
    var journalInsight: String?
    var moodSummaries: [MoodSummary] = []
    var personalityProfile: PersonalityProfile?

    // MARK: - Storage Keys

    private let storageKey = "journal_entries"
    private let summariesKey = "mood_summaries"
    private let profileKey = "personality_profile"
    private let kalmanKey = "kalman_state"
    private let baselineKey = "user_baseline"
    private let calibrationKey = "calibration_layer"

    // MARK: - Engine Layer

    private var pipeline: AnalysisPipeline
    private let moodProfiler = MoodProfiler()
    private var analyticsStore: MoodAnalyticsStore?
    private let personalityProfiler = PersonalityProfiler()

    // MARK: - Analysis Gating

    /// Prevents duplicate analysis for the same entry
    private var analysisInFlight: Set<UUID> = []

    /// Debounced refresh tasks — cancelled and re-created on each trigger
    private var insightTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?

    // MARK: - Init

    init(modelContainer: ModelContainer? = nil) {
        let kalman = Self.loadCodable(KalmanState.self, key: "kalman_state") ?? .initial
        let baseline = Self.loadCodable(UserBaseline.self, key: "user_baseline") ?? UserBaseline()
        let calibration = Self.loadCodable(CalibrationLayer.self, key: "calibration_layer") ?? .initial

        self.pipeline = AnalysisPipeline(
            kalmanState: kalman,
            baseline: baseline,
            calibration: calibration
        )

        if let container = modelContainer {
            self.analyticsStore = MoodAnalyticsStore(modelContainer: container)
        }

        load()
        scheduleRefreshInsight()
    }

    // MARK: - CRUD

    func add(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        save()
        runFullAnalysis(for: entry.id)
        BJHaptic.success()
    }

    func update(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            // Delete orphaned photos
            let oldIDs = entries[index].collage?.photoIDs ?? []
            let newIDs = Set(entry.collage?.photoIDs ?? [])
            let orphaned = oldIDs.filter { !newIDs.contains($0) }
            PhotoStorageManager.shared.deleteImages(ids: orphaned)

            // Delete orphaned drawing
            if let oldDrawing = entries[index].drawingID,
               oldDrawing != entry.drawingID {
                DrawingStorageManager.shared.delete(id: oldDrawing)
            }

            // ⚠️ KEY FIX: Keep old mood values intact — don't clear them.
            // The old moodScore stays visible until new analysis completes.
            var updated = entry
            updated.sentiment = entries[index].sentiment     // preserve
            updated.moodScore = entries[index].moodScore     // preserve
            updated.userEmotion = entries[index].userEmotion // preserve
            entries[index] = updated
            save()
            runFullAnalysis(for: entry.id)
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let entryID = entries[index].id
            if let photoIDs = entries[index].collage?.photoIDs {
                PhotoStorageManager.shared.deleteImages(ids: photoIDs)
            }
            if let drawingID = entries[index].drawingID {
                DrawingStorageManager.shared.delete(id: drawingID)
            }
            // Clean up analytics record
            Task { [weak self] in
                try? await self?.analyticsStore?.deleteRecord(noteID: entryID)
            }
        }
        entries.remove(atOffsets: offsets)
        save()
        scheduleRefreshInsight()
        scheduleRefreshProfiles()
        BJHaptic.warning()
    }

    /// Human-in-the-loop: user confirms an emotion from the top candidates.
    func confirmUserEmotion(for entryID: UUID, emotion: Sentiment) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].userEmotion = emotion
        entries[index].moodScore?.userConfirmedEmotion = emotion.rawValue

        // Record feedback for future prediction bias
        let text = entries[index].title + " " + entries[index].content
        MoodFeedbackStore.shared.recordCorrection(text: text, correctedMood: emotion)

        save()
        BJHaptic.success()
    }

    // MARK: - Full Analysis Pipeline

    private func runFullAnalysis(for entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              !entry.title.isEmpty || !entry.content.isEmpty
                || entry.collage?.photoIDs.isEmpty == false
                || entry.drawingID != nil
        else { return }

        // ⚠️ Gate: only one analysis per entry at a time
        guard !analysisInFlight.contains(entryID) else { return }
        analysisInFlight.insert(entryID)

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Load drawing if present
            var drawing: PKDrawing? = nil
            if let drawingID = entry.drawingID {
                drawing = DrawingStorageManager.shared.loadDrawing(id: drawingID)
            }

            // Run the full pipeline (single analysis — no separate SentimentAnalyzer call)
            let moodScore = await self.pipeline.analyze(
                title: entry.title,
                content: entry.content,
                photoIDs: entry.collage?.photoIDs ?? [],
                drawing: drawing,
                canvasSize: CGSize(width: 600, height: 400)
            )

            // Derive sentiment from the distribution (single source)
            let sentiment = Sentiment(rawValue: moodScore.primarySentiment) ?? .neutral

            // Persist engine state
            let kalman = await self.pipeline.getKalmanState()
            let baseline = await self.pipeline.getBaseline()
            let calibration = await self.pipeline.getCalibration()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.analysisInFlight.remove(entryID)

                if let index = self.entries.firstIndex(where: { $0.id == entryID }) {
                    // Atomic write — both fields from the same analysis
                    self.entries[index].moodScore = moodScore
                    self.entries[index].sentiment = sentiment
                    self.save()
                    self.saveEngineState(kalman: kalman, baseline: baseline, calibration: calibration)
                    self.scheduleRefreshInsight()
                    self.scheduleRefreshProfiles()

                    // Persist to siloed analytics store (fire-and-forget)
                    let savedEntry = self.entries[index]
                    Task { [weak self] in
                        try? await self?.analyticsStore?.recordMood(
                            from: savedEntry, moodScore: moodScore
                        )
                    }
                }
            }
        }
    }

    // MARK: - Debounced Insight Generation

    private func scheduleRefreshInsight() {
        insightTask?.cancel()
        insightTask = Task {
            // Wait 5 seconds before running (debounce rapid saves)
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await performRefreshInsight()
        }
    }

    private func performRefreshInsight() async {
        guard entries.count >= 5 else {
            await MainActor.run { journalInsight = nil }
            return
        }

        let recentEntries = Array(entries.prefix(5))
        guard let insight = await SentimentAnalyzer.generateInsight(from: recentEntries) else { return }
        await MainActor.run {
            journalInsight = insight
        }
    }

    // MARK: - Debounced Profiling

    private func scheduleRefreshProfiles() {
        profileTask?.cancel()
        profileTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await performRefreshProfiles()
        }
    }

    private func performRefreshProfiles() async {
        let summaries = await moodProfiler.buildRecentSummaries(entries: entries, days: 30)
        let profile = await personalityProfiler.updateProfile(
            from: summaries,
            entries: entries,
            existing: personalityProfile
        )

        await MainActor.run {
            self.moodSummaries = summaries
            self.personalityProfile = profile
            saveSummaries()
            saveProfile()
        }
    }

    // MARK: - Streaks

    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })

        guard !entryDays.isEmpty else { return 0 }

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

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = saved
        }
        loadSummaries()
        loadProfile()
    }

    private func saveSummaries() {
        if let data = try? JSONEncoder().encode(moodSummaries) {
            UserDefaults.standard.set(data, forKey: summariesKey)
        }
    }

    private func loadSummaries() {
        guard let data = UserDefaults.standard.data(forKey: summariesKey),
              let saved = try? JSONDecoder().decode([MoodSummary].self, from: data) else { return }
        moodSummaries = saved
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(personalityProfile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let saved = try? JSONDecoder().decode(PersonalityProfile.self, from: data) else { return }
        personalityProfile = saved
    }

    // MARK: - Engine State Persistence

    private func saveEngineState(kalman: KalmanState, baseline: UserBaseline, calibration: CalibrationLayer) {
        Self.saveCodable(kalman, key: kalmanKey)
        Self.saveCodable(baseline, key: baselineKey)
        Self.saveCodable(calibration, key: calibrationKey)
    }

    private static func saveCodable<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadCodable<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
