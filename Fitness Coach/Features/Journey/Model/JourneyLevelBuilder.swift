//
//  JourneyLevelBuilder.swift
//  Fitness Coach
//
//  Forma — Computed XP and level progression from real health behaviors.
//

import Foundation

enum JourneyLevelBuilder {

    struct Input: Equatable {
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var isAppleHealthConnected: Bool
        var unlockedMilestoneCount: Int
        var calendar: Calendar
    }

    private enum XPReward {
        static let foodLoggedDay = 10
        static let proteinGoalDay = 10
        static let waterGoalDay = 5
        static let calorieAdherenceDay = 10
        static let workoutDay = 15
        static let weightLoggedWeek = 10
        static let milestoneUnlock = 25
        static let maxDailyXP = 50
    }

    static func build(_ input: Input) -> JourneyLevelState {
        let copy = FormaProductCopy.Journey.Level.self
        let totalXP = computeTotalXP(input: input)
        let progress = levelProgress(totalXP: totalXP)
        let hasData = totalXP > 0

        return JourneyLevelState(
            currentLevel: progress.level,
            levelTitle: copy.title(for: progress.level),
            currentXP: progress.xpInLevel,
            xpRequiredForNextLevel: progress.xpRequired,
            totalXP: totalXP,
            progressPercent: progress.xpRequired > 0
                ? min(max(Double(progress.xpInLevel) / Double(progress.xpRequired) * 100, 0), 100)
                : 0,
            xpEarnedExplanation: hasData ? copy.earnExplanation : copy.emptyBody,
            hasData: hasData
        )
    }

    // MARK: - XP

    static func computeTotalXP(input: Input) -> Int {
        dailyBehaviorXP(input: input) + weightXP(input: input) + milestoneXP(input: input)
    }

    static func dailyBehaviorXP(input: Input) -> Int {
        let logsByDay = Dictionary(grouping: input.maturityLogs) {
            input.calendar.startOfDay(for: $0.date)
        }

        var total = 0
        for (day, logs) in logsByDay {
            guard let log = representativeLog(for: day, logs: logs) else { continue }
            var dayXP = 0

            if log.totals.calories > 0 {
                dayXP += XPReward.foodLoggedDay
            }
            if JourneyLogMetrics.proteinGoalDays(in: [log]) > 0 {
                dayXP += XPReward.proteinGoalDay
            }
            if JourneyLogMetrics.waterGoalDays(in: [log]) > 0 {
                dayXP += XPReward.waterGoalDay
            }
            if JourneyLogMetrics.calorieAdherenceDays(in: [log]) > 0 {
                dayXP += XPReward.calorieAdherenceDay
            }
            if input.isAppleHealthConnected, input.healthWorkoutDayStarts.contains(day) {
                dayXP += XPReward.workoutDay
            }

            total += min(dayXP, XPReward.maxDailyXP)
        }

        return total
    }

    static func weightXP(input: Input) -> Int {
        let sorted = input.allWeights
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }

        var awardedWeeks = Set<String>()
        var total = 0

        for entry in sorted {
            let weekKey = weekKey(for: entry.date, calendar: input.calendar)
            guard !awardedWeeks.contains(weekKey) else { continue }
            awardedWeeks.insert(weekKey)
            total += XPReward.weightLoggedWeek
        }

        return total
    }

    static func milestoneXP(input: Input) -> Int {
        input.unlockedMilestoneCount * XPReward.milestoneUnlock
    }

    // MARK: - Level curve

    static func xpRequiredToAdvance(fromLevel level: Int) -> Int {
        100 + level * 50
    }

    static func levelProgress(totalXP: Int) -> (level: Int, xpInLevel: Int, xpRequired: Int) {
        var level = 1
        var remaining = max(totalXP, 0)

        while remaining >= xpRequiredToAdvance(fromLevel: level) {
            remaining -= xpRequiredToAdvance(fromLevel: level)
            level += 1
        }

        return (level, remaining, xpRequiredToAdvance(fromLevel: level))
    }

    // MARK: - Helpers

    private static func representativeLog(for day: Date, logs: [DailyLog]) -> DailyLog? {
        logs.max { lhs, rhs in
            lhs.updatedAt < rhs.updatedAt
        }
    }

    private static func weekKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 0
        let week = components.weekOfYear ?? 0
        return "\(year)-\(week)"
    }
}
