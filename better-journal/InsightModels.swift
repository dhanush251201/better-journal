//
//  InsightModels.swift
//  better-journal
//
//  Data models for computed insights.
//  Consumed by views — kept separate from the InsightEngine actor.
//

import Foundation

// MARK: - Time-of-Day Insight

struct TimeOfDayInsight: Sendable, Identifiable {
    var id: String { peakPositiveWindow }
    var peakPositiveWindow: String       // e.g. "Morning"
    var peakPositiveValence: Double
    var peakStressWindow: String         // e.g. "Late Night"
    var peakStressValence: Double
    var buckets: [TimeBucket]

    struct TimeBucket: Sendable, Identifiable {
        var id: String { label }
        let label: String
        let averageValence: Double
        let averageArousal: Double
        let dominantMood: String
        let entryCount: Int
    }
}

// MARK: - Day-of-Week Insight

struct DayOfWeekInsight: Sendable {
    var bestDay: String                  // e.g. "Wednesday"
    var bestDayValence: Double
    var hardestDay: String
    var hardestDayValence: Double
    var days: [DayData]

    struct DayData: Sendable, Identifiable {
        var id: Int { dayOfWeek }
        let dayOfWeek: Int
        let dayName: String
        let averageValence: Double
        let averageIntensity: Double
        let variance: Double
        let dominantMood: String
        let entryCount: Int
    }
}

// MARK: - Streak Info

struct StreakInfo: Sendable {
    var journalingStreak: Int            // consecutive days with entries
    var positiveStreak: Int              // consecutive days with valence > 0.2
    var calmStreak: Int                  // consecutive days with arousal < 0.4
    var longestPositiveStreak: Int
    var longestCalmStreak: Int
}

// MARK: - Volatility Report

struct VolatilityInsight: Sendable {
    var valenceVariance: Double
    var averageSwing: Double
    var isUnstable: Bool
    var label: String                    // "Steady", "Variable", "Turbulent"
}

// MARK: - Seasonal Shift

struct SeasonalInsight: Sendable {
    var currentMonthLabel: String
    var previousMonthLabel: String
    var shiftPercentage: Double          // positive = improvement
    var shiftDirection: String           // "up", "down", "steady"
}

// MARK: - Natural Language Insight

struct NaturalInsight: Sendable, Identifiable {
    let id = UUID()
    let text: String
    let icon: String                     // SF Symbol name
    let category: InsightCategory

    enum InsightCategory: String, Sendable {
        case timeOfDay
        case dayOfWeek
        case streak
        case volatility
        case seasonal
        case milestone
    }
}

// MARK: - Weekly Summary Cache

struct WeeklySummaryCache: Codable, Sendable {
    let weekKey: String                  // ISO week: "2026-W08"
    let computedAt: Date
    let averageValence: Double
    let averageArousal: Double
    let dominantMood: String
    let entryCount: Int
    let topInsights: [String]            // pre-generated text insights
}

// MARK: - Sparkline Data Point

struct SparklinePoint: Sendable, Identifiable {
    var id: Date { date }
    let date: Date
    let valence: Double
    let intensity: Int
    let mood: String
}

// MARK: - Heatmap Day Data

struct HeatmapDay: Sendable, Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let mood: String?                    // nil = no entry
    let valence: Double
    let intensity: Int
    let entryCount: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
    }

    static func == (lhs: HeatmapDay, rhs: HeatmapDay) -> Bool {
        lhs.date == rhs.date
    }
}

// MARK: - Recap Card

enum RecapCard: Sendable, Identifiable {
    case energySummary(text: String, dominantMood: String)
    case steadiestDay(text: String, dayName: String)
    case highlightEntry(text: String, noteID: UUID, valence: Double)
    case weekComparison(text: String, shiftPercentage: Double)
    case milestone(text: String, milestoneType: MilestoneType)

    var id: String {
        switch self {
        case .energySummary: return "energy"
        case .steadiestDay: return "steadiest"
        case .highlightEntry: return "highlight"
        case .weekComparison: return "comparison"
        case .milestone(_, let type): return "milestone_\(type.rawValue)"
        }
    }

    enum MilestoneType: String, Sendable {
        case streak30 = "streak_30"
        case entries100 = "entries_100"
        case stabilityImproved = "stability_improved"
    }
}
