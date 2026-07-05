//
//  JourneyChapterBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic chapter progression from real logged events.
//

import Foundation

enum JourneyChapterBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var isAppleHealthConnected: Bool
        var unlockedMilestoneCount: Int
        var checkInStreakDays: Int
        var weeklyReviewUnlocked: Bool
        var calendar: Calendar
    }

    private enum XPReward {
        static let foodLoggedDay = 10
        static let proteinGoalDay = 10
        static let waterGoalDay = 5
        static let workoutDay = 15
        static let weightLoggedWeek = 10
        static let milestoneUnlock = 25
        static let completedWeek = 20
        static let maxDailyXP = 40
        static let minimumFoodDaysForCompletedWeek = 5
    }

    static let chapterCount = 5
    static let xpPerChapter = 200

    static func build(_ input: Input) -> JourneyChapterState {
        let copy = FormaProductCopy.Journey.Chapters.self
        let totalXP = computeTotalXP(input: input)
        let progress = chapterProgress(totalXP: totalXP)
        let nextTitle = progress.chapter < chapterCount
            ? copy.title(for: progress.chapter + 1)
            : nil

        let progressItems = chapterOneProgressItems(input: input, copy: copy)
        let actionProgressPercent = actionProgressPercent(from: progressItems)

        let progressPercent: Double
        if progress.chapter == 1, !progressItems.isEmpty {
            progressPercent = actionProgressPercent
        } else {
            progressPercent = progress.xpRequired > 0
                ? min(max(Double(progress.xpInChapter) / Double(progress.xpRequired) * 100, 0), 100)
                : 0
        }

        let chapterTitle = copy.title(for: progress.chapter)
        let nextUnlock = nextTitle.map { copy.nextUnlock($0) }
        let itemSummary = progressItems
            .map(\.accessibilityLabel)
            .joined(separator: ". ")
        let accessibilitySummary = [
            copy.sectionTitle,
            copy.chapterLabel(progress.chapter),
            chapterTitle,
            nextUnlock,
            itemSummary
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")

        return JourneyChapterState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            chapterNumber: progress.chapter,
            chapterTitle: chapterTitle,
            nextUnlockLabel: nextUnlock,
            progressPercent: progressPercent,
            emptyMessage: totalXP == 0 && progressItems.allSatisfy { !$0.isCompleted } ? copy.emptyBody : nil,
            totalXP: totalXP,
            progressItems: progress.chapter == 1 ? progressItems : [],
            accessibilitySummary: accessibilitySummary
        )
    }

    // MARK: - Chapter 1 action progress

    static func chapterOneProgressItems(
        input: Input,
        copy: FormaProductCopy.Journey.Chapters.Type
    ) -> [JourneyUnlockChecklistItem] {
        let requiredCheckInDays = JourneyThresholds.chapterCheckInStreakDays
        let requiredReviewDays = JourneyThresholds.requiredCalendarSpanDays
        let hasStartedForma = input.profile != nil
        let hasWeighIn = input.allWeights.contains { $0.weightKg > 0 }
        let hasWorkout = hasCompletedWorkout(input: input)
        let hasMeal = input.maturityLogs.contains { $0.totals.calories > 0 }

        return [
            progressItem(
                id: "started-forma",
                title: copy.startedForma,
                isComplete: hasStartedForma
            ),
            progressItem(
                id: "first-weigh-in",
                title: copy.firstWeighIn,
                isComplete: hasWeighIn
            ),
            progressItem(
                id: "first-workout",
                title: copy.firstWorkout,
                isComplete: hasWorkout
            ),
            progressItem(
                id: "first-meal",
                title: copy.firstMeal,
                isComplete: hasMeal
            ),
            streakProgressItem(
                id: "check-in-streak",
                title: copy.checkInStreak(days: requiredCheckInDays),
                current: input.checkInStreakDays,
                required: requiredCheckInDays
            ),
            streakProgressItem(
                id: "weekly-review",
                title: copy.weeklyReviewUnlocked(days: requiredReviewDays),
                current: input.weeklyReviewUnlocked ? requiredReviewDays : 0,
                required: requiredReviewDays
            )
        ]
    }

    static func actionProgressPercent(from items: [JourneyUnlockChecklistItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        let completed = items.filter(\.isCompleted).count
        return min(max(Double(completed) / Double(items.count) * 100, 0), 100)
    }

    private static func hasCompletedWorkout(input: Input) -> Bool {
        if !input.healthWorkoutDayStarts.isEmpty {
            return true
        }
        return input.maturityLogs.contains { $0.workoutCaloriesBurned > 0 }
    }

    private static func progressItem(
        id: String,
        title: String,
        isComplete: Bool
    ) -> JourneyUnlockChecklistItem {
        let status: JourneyUnlockChecklistItemStatus = isComplete ? .completed : .pending
        let accessibility = isComplete
            ? "\(title). Completed."
            : "\(title). Not yet completed."
        return JourneyUnlockChecklistItem(
            id: id,
            title: title,
            status: status,
            accessibilityLabel: accessibility
        )
    }

    private static func streakProgressItem(
        id: String,
        title: String,
        current: Int,
        required: Int
    ) -> JourneyUnlockChecklistItem {
        let status: JourneyUnlockChecklistItemStatus
        if current >= required {
            status = .completed
        } else if current > 0 {
            status = .inProgress(current: current, total: required)
        } else {
            status = .pending
        }

        let accessibility: String
        switch status {
        case .completed:
            accessibility = "\(title). Completed."
        case .inProgress(let current, let total):
            accessibility = "\(title). \(current) of \(total)."
        case .pending:
            accessibility = "\(title). Not yet completed."
        }

        return JourneyUnlockChecklistItem(
            id: id,
            title: title,
            status: status,
            accessibilityLabel: accessibility
        )
    }

    // MARK: - XP

    static func computeTotalXP(input: Input) -> Int {
        max(
            0,
            dailyBehaviorXP(input: input)
                + weightXP(input: input)
                + completedWeekXP(input: input)
                + milestoneXP(input: input)
        )
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
            let key = weekKey(for: entry.date, calendar: input.calendar)
            guard !awardedWeeks.contains(key) else { continue }
            awardedWeeks.insert(key)
            total += XPReward.weightLoggedWeek
        }

        return total
    }

    static func completedWeekXP(input: Input) -> Int {
        let logsByDay = Dictionary(grouping: input.maturityLogs) {
            input.calendar.startOfDay(for: $0.date)
        }

        var foodDaysByWeek: [String: Set<Date>] = [:]
        for (day, logs) in logsByDay {
            guard let log = representativeLog(for: day, logs: logs), log.totals.calories > 0 else {
                continue
            }
            let key = weekKey(for: day, calendar: input.calendar)
            foodDaysByWeek[key, default: []].insert(day)
        }

        let completedWeeks = foodDaysByWeek.values.filter {
            $0.count >= XPReward.minimumFoodDaysForCompletedWeek
        }.count

        return completedWeeks * XPReward.completedWeek
    }

    static func milestoneXP(input: Input) -> Int {
        input.unlockedMilestoneCount * XPReward.milestoneUnlock
    }

    // MARK: - Chapter curve

    static func chapterProgress(totalXP: Int) -> (chapter: Int, xpInChapter: Int, xpRequired: Int) {
        let clampedXP = max(totalXP, 0)
        let zeroBasedChapter = min(chapterCount - 1, clampedXP / xpPerChapter)
        let chapter = zeroBasedChapter + 1
        let xpInChapter = clampedXP - (zeroBasedChapter * xpPerChapter)

        if chapter >= chapterCount {
            return (chapterCount, xpPerChapter, xpPerChapter)
        }

        return (chapter, xpInChapter, xpPerChapter)
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
