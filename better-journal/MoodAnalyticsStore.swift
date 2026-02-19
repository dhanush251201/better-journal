//
//  MoodAnalyticsStore.swift
//  better-journal
//
//  ModelActor-based store for siloed mood analytics.
//  All queries operate on MoodAnalyticsRecord only —
//  journal text is never loaded or referenced.
//

import Foundation
import SwiftData

// MARK: - MoodAnalyticsStore

@ModelActor
actor MoodAnalyticsStore {

    // MARK: - Write

    /// Persist mood metadata from a completed analysis.
    /// Upserts: if a record for this noteID exists, it is replaced.
    func recordMood(from entry: JournalEntry, moodScore: MoodScore) throws {
        // Delete existing record for this entry (upsert)
        let noteID = entry.id
        let existing = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate { $0.noteID == noteID }
        )
        let found = try modelContext.fetch(existing)
        for record in found {
            modelContext.delete(record)
        }

        let record = MoodAnalyticsRecord.from(entry: entry, moodScore: moodScore)
        modelContext.insert(record)
        try modelContext.save()
    }

    /// Delete analytics record when a journal entry is deleted.
    func deleteRecord(noteID: UUID) throws {
        let descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate { $0.noteID == noteID }
        )
        let found = try modelContext.fetch(descriptor)
        for record in found {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    // MARK: - Time-of-Day Aggregation

    struct TimeOfDayBucket: Sendable {
        let label: String          // "Morning", "Afternoon", etc.
        let hourRange: ClosedRange<Int>
        var averageValence: Double
        var averageArousal: Double
        var dominantMood: String
        var entryCount: Int
    }

    /// Average valence/arousal grouped by time-of-day buckets.
    func fetchTimeOfDayAverages(from startDate: Date, to endDate: Date) throws -> [TimeOfDayBucket] {
        let descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            }
        )
        let records = try modelContext.fetch(descriptor)

        let buckets: [(String, ClosedRange<Int>)] = [
            ("Morning",    5...11),
            ("Afternoon", 12...16),
            ("Evening",   17...21),
            ("Late Night", 0...4),  // Also includes 22–23 below
        ]

        return buckets.map { label, range in
            let matching = records.filter { rec in
                if label == "Late Night" {
                    return rec.hourOfDay >= 22 || rec.hourOfDay <= 4
                }
                return range.contains(rec.hourOfDay)
            }

            guard !matching.isEmpty else {
                return TimeOfDayBucket(
                    label: label, hourRange: range,
                    averageValence: 0, averageArousal: 0.3,
                    dominantMood: "neutral", entryCount: 0
                )
            }

            let avgV = matching.map(\.valence).reduce(0, +) / Double(matching.count)
            let avgA = matching.map(\.arousal).reduce(0, +) / Double(matching.count)
            let dominant = Self.dominantCategory(in: matching)

            return TimeOfDayBucket(
                label: label, hourRange: range,
                averageValence: avgV, averageArousal: avgA,
                dominantMood: dominant, entryCount: matching.count
            )
        }
    }

    // MARK: - Day-of-Week Aggregation

    struct DayOfWeekTrend: Sendable {
        let dayOfWeek: Int         // 1 (Sun) – 7 (Sat)
        let dayName: String
        var averageValence: Double
        var averageIntensity: Double
        var variance: Double
        var dominantMood: String
        var entryCount: Int
    }

    /// Average intensity and mood distribution per weekday.
    func fetchDayOfWeekTrends(from startDate: Date, to endDate: Date) throws -> [DayOfWeekTrend] {
        let descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            }
        )
        let records = try modelContext.fetch(descriptor)

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return (1...7).map { day in
            let matching = records.filter { $0.dayOfWeek == day }

            guard !matching.isEmpty else {
                return DayOfWeekTrend(
                    dayOfWeek: day, dayName: dayNames[day - 1],
                    averageValence: 0, averageIntensity: 0,
                    variance: 0, dominantMood: "neutral", entryCount: 0
                )
            }

            let avgV = matching.map(\.valence).reduce(0, +) / Double(matching.count)
            let avgI = matching.map { Double($0.moodIntensity) }.reduce(0, +) / Double(matching.count)
            let variance = Self.computeVariance(matching.map(\.valence))
            let dominant = Self.dominantCategory(in: matching)

            return DayOfWeekTrend(
                dayOfWeek: day, dayName: dayNames[day - 1],
                averageValence: avgV, averageIntensity: avgI,
                variance: variance, dominantMood: dominant,
                entryCount: matching.count
            )
        }
    }

    // MARK: - Mood Distribution

    struct MoodDistributionItem: Sendable {
        let category: String
        var count: Int
        var percentage: Double
    }

    /// Mood category frequency distribution for a date range.
    func fetchMoodDistribution(from startDate: Date, to endDate: Date) throws -> [MoodDistributionItem] {
        let descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            }
        )
        let records = try modelContext.fetch(descriptor)
        guard !records.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for record in records {
            counts[record.moodCategory, default: 0] += 1
        }

        let total = Double(records.count)
        return counts.map { category, count in
            MoodDistributionItem(
                category: category,
                count: count,
                percentage: Double(count) / total
            )
        }.sorted { $0.count > $1.count }
    }

    // MARK: - Volatility

    struct VolatilityReport: Sendable {
        var valenceVariance: Double
        var averageSwing: Double       // mean |Δvalence| between consecutive entries
        var isUnstable: Bool           // variance > threshold
        var periodLabel: String
    }

    /// Measure emotional volatility over a date range.
    func fetchVolatility(from startDate: Date, to endDate: Date) throws -> VolatilityReport {
        var descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate {
                $0.timestamp >= startDate && $0.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        let records = try modelContext.fetch(descriptor)

        let valences = records.map(\.valence)
        let variance = Self.computeVariance(valences)

        var totalSwing = 0.0
        if valences.count >= 2 {
            for i in 1..<valences.count {
                totalSwing += abs(valences[i] - valences[i - 1])
            }
            totalSwing /= Double(valences.count - 1)
        }

        return VolatilityReport(
            valenceVariance: variance,
            averageSwing: totalSwing,
            isUnstable: variance > 0.25,
            periodLabel: Self.periodLabel(from: startDate, to: endDate)
        )
    }

    // MARK: - Seasonal Shift

    struct SeasonalShift: Sendable {
        var currentMonthAvgValence: Double
        var previousMonthAvgValence: Double
        var shift: Double              // current - previous (positive = improvement)
        var shiftPercentage: Double
    }

    /// Compare current month vs previous month average valence.
    func fetchSeasonalShift() throws -> SeasonalShift? {
        let cal = Calendar.current
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let currentYear = cal.component(.year, from: now)

        let prevDate = cal.date(byAdding: .month, value: -1, to: now)!
        let prevMonth = cal.component(.month, from: prevDate)
        let prevYear = cal.component(.year, from: prevDate)

        let currentDescriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate {
                $0.monthOfYear == currentMonth && $0.yearValue == currentYear
            }
        )
        let prevDescriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate {
                $0.monthOfYear == prevMonth && $0.yearValue == prevYear
            }
        )

        let currentRecords = try modelContext.fetch(currentDescriptor)
        let prevRecords = try modelContext.fetch(prevDescriptor)

        guard !currentRecords.isEmpty, !prevRecords.isEmpty else { return nil }

        let currentAvg = currentRecords.map(\.valence).reduce(0, +) / Double(currentRecords.count)
        let prevAvg = prevRecords.map(\.valence).reduce(0, +) / Double(prevRecords.count)
        let shift = currentAvg - prevAvg
        let pct = prevAvg != 0 ? (shift / abs(prevAvg)) * 100 : 0

        return SeasonalShift(
            currentMonthAvgValence: currentAvg,
            previousMonthAvgValence: prevAvg,
            shift: shift,
            shiftPercentage: pct
        )
    }

    // MARK: - Recent Records (for sparkline)

    /// Fetch records for the last N days, sorted by timestamp.
    func fetchRecentRecords(days: Int) throws -> [MoodAnalyticsRecord] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date())!
        var descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate { $0.timestamp >= cutoff },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all records for the past year (heatmap).
    func fetchYearRecords() throws -> [MoodAnalyticsRecord] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .year, value: -1, to: Date())!
        var descriptor = FetchDescriptor<MoodAnalyticsRecord>(
            predicate: #Predicate { $0.timestamp >= cutoff },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]
        return try modelContext.fetch(descriptor)
    }

    /// Total record count.
    func totalEntryCount() throws -> Int {
        let descriptor = FetchDescriptor<MoodAnalyticsRecord>()
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Helpers

    private static func dominantCategory(in records: [MoodAnalyticsRecord]) -> String {
        var counts: [String: Int] = [:]
        for r in records { counts[r.moodCategory, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? "neutral"
    }

    private static func computeVariance(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSq = values.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSq / Double(values.count - 1)
    }

    private static func periodLabel(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
