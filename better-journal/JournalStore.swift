//
//  JournalStore.swift
//  better-journal
//
//  Created by Dhanush Gowdhaman on 2/11/26.
//
//  Persists journal entries, mood engine state (Kalman / Baseline / Calibration),
//  mood summaries, and personality profiles. All data stored locally via UserDefaults.
//

import Foundation
import Observation
import PencilKit
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
    private let personalityProfiler = PersonalityProfiler()

    // MARK: - Init

    init() {
        // Load persisted engine state
        let kalman = Self.loadCodable(KalmanState.self, key: "kalman_state") ?? .initial
        let baseline = Self.loadCodable(UserBaseline.self, key: "user_baseline") ?? UserBaseline()
        let calibration = Self.loadCodable(CalibrationLayer.self, key: "calibration_layer") ?? .initial

        self.pipeline = AnalysisPipeline(
            kalmanState: kalman,
            baseline: baseline,
            calibration: calibration
        )

        load()
        refreshInsight()
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

            var updated = entry
            updated.sentiment = nil
            updated.moodScore = nil
            entries[index] = updated
            save()
            runFullAnalysis(for: entry.id)
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            if let photoIDs = entries[index].collage?.photoIDs {
                PhotoStorageManager.shared.deleteImages(ids: photoIDs)
            }
            if let drawingID = entries[index].drawingID {
                DrawingStorageManager.shared.delete(id: drawingID)
            }
        }
        entries.remove(atOffsets: offsets)
        save()
        refreshInsight()
        refreshProfiles()
        BJHaptic.warning()
    }

    // MARK: - Full Analysis Pipeline

    private func runFullAnalysis(for entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }),
              !entry.title.isEmpty || !entry.content.isEmpty
                || entry.collage?.photoIDs.isEmpty == false
                || entry.drawingID != nil
        else { return }

        Task {
            // Load drawing if present
            var drawing: PKDrawing? = nil
            if let drawingID = entry.drawingID {
                drawing = DrawingStorageManager.shared.loadDrawing(id: drawingID)
            }

            // Run the 6-layer pipeline
            let moodScore = await pipeline.analyze(
                title: entry.title,
                content: entry.content,
                photoIDs: entry.collage?.photoIDs ?? [],
                drawing: drawing,
                canvasSize: CGSize(width: 600, height: 400)
            )

            // Also get text-only sentiment for backward compat display
            let sentiment = await SentimentAnalyzer.analyze(title: entry.title, content: entry.content)

            // Persist engine state after each analysis
            let kalman = await pipeline.getKalmanState()
            let baseline = await pipeline.getBaseline()
            let calibration = await pipeline.getCalibration()

            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == entryID }) {
                    entries[index].moodScore = moodScore
                    entries[index].sentiment = sentiment
                    save()
                    saveEngineState(kalman: kalman, baseline: baseline, calibration: calibration)
                    refreshInsight()
                    refreshProfiles()
                }
            }
        }
    }

    // MARK: - Insight Generation

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

    // MARK: - Profiling

    func refreshProfiles() {
        Task {
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
