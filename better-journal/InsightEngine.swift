//
//  InsightEngine.swift
//  better-journal
//
//  Modular analysis engine that runs on metadata only.
//  Consumes MoodAnalyticsStore queries and produces
//  InsightModels for the UI layer. Never touches journal text.
//

import Foundation
import SwiftData

actor InsightEngine {

    private let analyticsStore: MoodAnalyticsStore

    // MARK: - Cache

    private var cachedWeeklySummaries: [String: WeeklySummaryCache] = [:]
    private var lastComputedInsights: Date?

    init(modelContainer: ModelContainer) {
        self.analyticsStore = MoodAnalyticsStore(modelContainer: modelContainer)
        loadCache()
    }

    // MARK: - Time-of-Day Correlation

    func computeTimeOfDayInsight(days: Int = 30) async -> TimeOfDayInsight? {
        let (start, end) = dateRange(days: days)

        guard let buckets = try? await analyticsStore.fetchTimeOfDayAverages(
            from: start, to: end
        ), !buckets.isEmpty else { return nil }

        let mapped = buckets.map { b in
            TimeOfDayInsight.TimeBucket(
                label: b.label,
                averageValence: b.averageValence,
                averageArousal: b.averageArousal,
                dominantMood: b.dominantMood,
                entryCount: b.entryCount
            )
        }

        let activeBuckets = mapped.filter { $0.entryCount > 0 }
        guard !activeBuckets.isEmpty else { return nil }

        let peak = activeBuckets.max(by: { $0.averageValence < $1.averageValence })!
        let stress = activeBuckets.min(by: { $0.averageValence < $1.averageValence })!

        return TimeOfDayInsight(
            peakPositiveWindow: peak.label,
            peakPositiveValence: peak.averageValence,
            peakStressWindow: stress.label,
            peakStressValence: stress.averageValence,
            buckets: mapped
        )
    }

    // MARK: - Day-of-Week Trends

    func computeDayOfWeekInsight(days: Int = 30) async -> DayOfWeekInsight? {
        let (start, end) = dateRange(days: days)

        guard let trends = try? await analyticsStore.fetchDayOfWeekTrends(
            from: start, to: end
        ) else { return nil }

        let active = trends.filter { $0.entryCount > 0 }
        guard !active.isEmpty else { return nil }

        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let best = active.max(by: { $0.averageValence < $1.averageValence })!
        let hardest = active.min(by: { $0.averageValence < $1.averageValence })!

        let days = trends.map { t in
            DayOfWeekInsight.DayData(
                dayOfWeek: t.dayOfWeek,
                dayName: t.dayName,
                averageValence: t.averageValence,
                averageIntensity: t.averageIntensity,
                variance: t.variance,
                dominantMood: t.dominantMood,
                entryCount: t.entryCount
            )
        }

        return DayOfWeekInsight(
            bestDay: dayNames[best.dayOfWeek - 1],
            bestDayValence: best.averageValence,
            hardestDay: dayNames[hardest.dayOfWeek - 1],
            hardestDayValence: hardest.averageValence,
            days: days
        )
    }

    // MARK: - Streak Detection

    func computeStreaks() async -> StreakInfo {
        guard let records = try? await analyticsStore.fetchRecentRecords(days: 365) else {
            return StreakInfo(journalingStreak: 0, positiveStreak: 0, calmStreak: 0,
                             longestPositiveStreak: 0, longestCalmStreak: 0)
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Group records by day
        var dayMap: [Date: [MoodAnalyticsRecord]] = [:]
        for record in records {
            let day = cal.startOfDay(for: record.timestamp)
            dayMap[day, default: []].append(record)
        }

        // Journaling streak (consecutive days with entries)
        let journalingStreak = computeConsecutiveStreak(from: today, dayMap: dayMap) { !$0.isEmpty }

        // Positive streak (consecutive days with avg valence > 0.2)
        var positiveStreak = 0
        var longestPositive = 0
        var currentPositive = 0
        for dayOffset in 0..<365 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today),
                  let recs = dayMap[date] else {
                longestPositive = max(longestPositive, currentPositive)
                currentPositive = 0
                continue
            }
            let avgV = recs.map(\.valence).reduce(0, +) / Double(recs.count)
            if avgV > 0.2 {
                currentPositive += 1
                if dayOffset < 60 { positiveStreak = currentPositive }
            } else {
                longestPositive = max(longestPositive, currentPositive)
                currentPositive = 0
                if dayOffset < positiveStreak { break }
            }
        }
        longestPositive = max(longestPositive, currentPositive)

        // Calm streak (consecutive days with avg arousal < 0.4)
        var calmStreak = 0
        var longestCalm = 0
        var currentCalm = 0
        for dayOffset in 0..<365 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today),
                  let recs = dayMap[date] else {
                longestCalm = max(longestCalm, currentCalm)
                currentCalm = 0
                continue
            }
            let avgA = recs.map(\.arousal).reduce(0, +) / Double(recs.count)
            if avgA < 0.4 {
                currentCalm += 1
                if dayOffset < 60 { calmStreak = currentCalm }
            } else {
                longestCalm = max(longestCalm, currentCalm)
                currentCalm = 0
                if dayOffset < calmStreak { break }
            }
        }
        longestCalm = max(longestCalm, currentCalm)

        return StreakInfo(
            journalingStreak: journalingStreak,
            positiveStreak: positiveStreak,
            calmStreak: calmStreak,
            longestPositiveStreak: longestPositive,
            longestCalmStreak: longestCalm
        )
    }

    // MARK: - Volatility Detection

    func computeVolatility(days: Int = 14) async -> VolatilityInsight {
        let (start, end) = dateRange(days: days)

        guard let report = try? await analyticsStore.fetchVolatility(from: start, to: end) else {
            return VolatilityInsight(valenceVariance: 0, averageSwing: 0,
                                    isUnstable: false, label: "Not enough data")
        }

        let label: String
        if report.valenceVariance > 0.35 {
            label = "Turbulent"
        } else if report.valenceVariance > 0.15 {
            label = "Variable"
        } else {
            label = "Steady"
        }

        return VolatilityInsight(
            valenceVariance: report.valenceVariance,
            averageSwing: report.averageSwing,
            isUnstable: report.isUnstable,
            label: label
        )
    }

    // MARK: - Seasonal Patterning

    func computeSeasonalInsight() async -> SeasonalInsight? {
        guard let shift = try? await analyticsStore.fetchSeasonalShift() else { return nil }

        let cal = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        let currentLabel = formatter.string(from: now)
        let prevDate = cal.date(byAdding: .month, value: -1, to: now)!
        let prevLabel = formatter.string(from: prevDate)

        let direction: String
        if shift.shiftPercentage > 5 {
            direction = "up"
        } else if shift.shiftPercentage < -5 {
            direction = "down"
        } else {
            direction = "steady"
        }

        return SeasonalInsight(
            currentMonthLabel: currentLabel,
            previousMonthLabel: prevLabel,
            shiftPercentage: shift.shiftPercentage,
            shiftDirection: direction
        )
    }

    // MARK: - Natural Language Insight Generation

    func generateNaturalInsights(days: Int = 30) async -> [NaturalInsight] {
        var insights: [NaturalInsight] = []

        // Time-of-day
        if let tod = await computeTimeOfDayInsight(days: days) {
            let peakMood = Sentiment(rawValue: tod.buckets.first(where: { $0.label == tod.peakPositiveWindow })?.dominantMood ?? "happy")?.displayName ?? "positive"
            insights.append(NaturalInsight(
                text: "You tend to feel most \(peakMood.lowercased()) during \(tod.peakPositiveWindow.lowercased())s.",
                icon: "sunrise.fill",
                category: .timeOfDay
            ))
        }

        // Day-of-week
        if let dow = await computeDayOfWeekInsight(days: days) {
            let bestMood = Sentiment(rawValue: dow.days.first(where: { $0.dayName == dow.bestDay.prefix(3).description })?.dominantMood ?? "happy")?.displayName ?? "energized"
            insights.append(NaturalInsight(
                text: "You tend to feel most \(bestMood.lowercased()) on \(dow.bestDay)s.",
                icon: "calendar.circle.fill",
                category: .dayOfWeek
            ))
        }

        // Streaks
        let streaks = await computeStreaks()
        if streaks.positiveStreak >= 3 {
            insights.append(NaturalInsight(
                text: "You're on a \(streaks.positiveStreak)-day positive streak. Keep it going!",
                icon: "flame.fill",
                category: .streak
            ))
        }
        if streaks.calmStreak >= 3 {
            insights.append(NaturalInsight(
                text: "You've been calm for \(streaks.calmStreak) days in a row.",
                icon: "leaf.fill",
                category: .streak
            ))
        }

        // Volatility
        let vol = await computeVolatility(days: 14)
        if vol.label == "Steady" {
            insights.append(NaturalInsight(
                text: "Your emotional landscape has been steady lately.",
                icon: "waveform.path",
                category: .volatility
            ))
        } else if vol.label == "Turbulent" {
            insights.append(NaturalInsight(
                text: "Your emotions have been more dynamic recently. That's okay — growth often comes in waves.",
                icon: "water.waves",
                category: .volatility
            ))
        }

        // Seasonal
        if let seasonal = await computeSeasonalInsight() {
            if seasonal.shiftDirection == "up" {
                insights.append(NaturalInsight(
                    text: "Your mood has lifted \(Int(abs(seasonal.shiftPercentage)))% compared to \(seasonal.previousMonthLabel).",
                    icon: "arrow.up.heart.fill",
                    category: .seasonal
                ))
            } else if seasonal.shiftDirection == "down" {
                insights.append(NaturalInsight(
                    text: "This \(seasonal.currentMonthLabel) has been more reflective than \(seasonal.previousMonthLabel).",
                    icon: "moon.fill",
                    category: .seasonal
                ))
            }
        }

        return insights
    }

    // MARK: - Sparkline Data

    func fetchSparklineData(days: Int = 7) async -> [SparklinePoint] {
        guard let records = try? await analyticsStore.fetchRecentRecords(days: days) else {
            return []
        }

        // Group by day, average
        let cal = Calendar.current
        var dayMap: [Date: [MoodAnalyticsRecord]] = [:]
        for record in records {
            let day = cal.startOfDay(for: record.timestamp)
            dayMap[day, default: []].append(record)
        }

        let today = cal.startOfDay(for: Date())
        return (0..<days).compactMap { offset -> SparklinePoint? in
            guard let date = cal.date(byAdding: .day, value: -(days - 1 - offset), to: today) else { return nil }
            let recs = dayMap[date] ?? []
            let valence = recs.isEmpty ? 0 : recs.map(\.valence).reduce(0, +) / Double(recs.count)
            let intensity = recs.isEmpty ? 0 : recs.map(\.moodIntensity).reduce(0, +) / recs.count
            let mood = recs.isEmpty ? "neutral" : Self.dominantCategory(in: recs)
            return SparklinePoint(date: date, valence: valence, intensity: intensity, mood: mood)
        }
    }

    // MARK: - Heatmap Data

    func fetchHeatmapData() async -> [HeatmapDay] {
        guard let records = try? await analyticsStore.fetchYearRecords() else { return [] }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var dayMap: [Date: [MoodAnalyticsRecord]] = [:]
        for record in records {
            let day = cal.startOfDay(for: record.timestamp)
            dayMap[day, default: []].append(record)
        }

        return (0..<365).compactMap { offset -> HeatmapDay? in
            guard let date = cal.date(byAdding: .day, value: -(364 - offset), to: today) else { return nil }
            let recs = dayMap[date] ?? []
            if recs.isEmpty {
                return HeatmapDay(date: date, mood: nil, valence: 0, intensity: 0, entryCount: 0)
            }
            let valence = recs.map(\.valence).reduce(0, +) / Double(recs.count)
            let intensity = recs.map(\.moodIntensity).reduce(0, +) / recs.count
            let mood = Self.dominantCategory(in: recs)
            return HeatmapDay(date: date, mood: mood, valence: valence, intensity: intensity, entryCount: recs.count)
        }
    }

    // MARK: - Mood Distribution (for ring chart)

    func fetchMoodDistribution(days: Int = 30) async -> [MoodAnalyticsStore.MoodDistributionItem] {
        let (start, end) = dateRange(days: days)
        return (try? await analyticsStore.fetchMoodDistribution(from: start, to: end)) ?? []
    }

    // MARK: - Recap Generation

    func generateRecapCards() async -> [RecapCard] {
        var cards: [RecapCard] = []

        // Card 1: Energy summary
        if let tod = await computeTimeOfDayInsight(days: 7) {
            let dominantMood = tod.buckets.max(by: { $0.entryCount < $1.entryCount })?.dominantMood ?? "calm"
            let moodName = Sentiment(rawValue: dominantMood)?.displayName ?? dominantMood.capitalized
            cards.append(.energySummary(
                text: "Your week had strong \(moodName.lowercased()) energy.",
                dominantMood: dominantMood
            ))
        }

        // Card 2: Steadiest day
        if let dow = await computeDayOfWeekInsight(days: 7) {
            let steadiest = dow.days.filter { $0.entryCount > 0 }
                .min(by: { $0.variance < $1.variance })
            if let day = steadiest {
                let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                let dayName = dayNames[day.dayOfWeek - 1]
                cards.append(.steadiestDay(
                    text: "You felt most steady on \(dayName).",
                    dayName: dayName
                ))
            }
        }

        // Card 3: Best note highlight
        if let records = try? await analyticsStore.fetchRecentRecords(days: 7) {
            if let best = records.max(by: { $0.valence < $1.valence }) {
                let moodName = Sentiment(rawValue: best.moodCategory)?.displayName ?? best.moodCategory.capitalized
                cards.append(.highlightEntry(
                    text: "Your brightest moment was one of \(moodName.lowercased()).",
                    noteID: best.noteID,
                    valence: best.valence
                ))
            }
        }

        // Card 4: Week-over-week comparison
        let thisWeekRecords = try? await analyticsStore.fetchRecentRecords(days: 7)
        let cal = Calendar.current
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: Date())!
        let oneWeekAgo = cal.date(byAdding: .day, value: -7, to: Date())!

        if let thisWeek = thisWeekRecords, !thisWeek.isEmpty {
            let thisAvg = thisWeek.map(\.valence).reduce(0, +) / Double(thisWeek.count)

            if let lastWeekRecords = try? await analyticsStore.fetchRecentRecords(days: 14) {
                let lastWeek = lastWeekRecords.filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < oneWeekAgo }
                if !lastWeek.isEmpty {
                    let lastAvg = lastWeek.map(\.valence).reduce(0, +) / Double(lastWeek.count)
                    let shift = lastAvg != 0 ? ((thisAvg - lastAvg) / abs(lastAvg)) * 100 : 0
                    let direction = shift > 0 ? "lifted" : "softened"
                    cards.append(.weekComparison(
                        text: "Your mood \(direction) \(Int(abs(shift)))% compared to last week.",
                        shiftPercentage: shift
                    ))
                }
            }
        }

        // Milestone checks
        let totalCount = (try? await analyticsStore.totalEntryCount()) ?? 0
        if totalCount >= 100 {
            cards.append(.milestone(
                text: "You've written \(totalCount) journal entries. What a journey.",
                milestoneType: .entries100
            ))
        }

        let streaks = await computeStreaks()
        if streaks.positiveStreak >= 30 {
            cards.append(.milestone(
                text: "30 days of positive energy. You're building something beautiful.",
                milestoneType: .streak30
            ))
        }

        return cards
    }

    // MARK: - Helpers

    private func dateRange(days: Int) -> (Date, Date) {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end)!
        return (start, end)
    }

    private func computeConsecutiveStreak(
        from today: Date,
        dayMap: [Date: [MoodAnalyticsRecord]],
        predicate: ([MoodAnalyticsRecord]) -> Bool
    ) -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = today

        // Allow today or yesterday as start
        if let recs = dayMap[checkDate], predicate(recs) {
            // start is today
        } else {
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            guard let recs = dayMap[checkDate], predicate(recs) else { return 0 }
        }

        while let recs = dayMap[checkDate], predicate(recs) {
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    private static func dominantCategory(in records: [MoodAnalyticsRecord]) -> String {
        var counts: [String: Int] = [:]
        for r in records { counts[r.moodCategory, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key ?? "neutral"
    }

    // MARK: - Cache Persistence

    private static let cacheKey = "insight_weekly_cache"

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode([String: WeeklySummaryCache].self, from: data)
        else { return }
        cachedWeeklySummaries = cached
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(cachedWeeklySummaries) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }
}
