//
//  JourneyStreakBuilder.swift
//  Fitness Coach
//
//  Forma — Journey streak state and supportive consistency copy.
//

import Foundation

enum JourneyStreakBuilder {

    struct Input: Equatable {
        var streakSummary: StreakSummary
        var maturityLogs: [DailyLog]
        var workoutDates: Set<Date>
        var isAppleHealthConnected: Bool
        var asOf: Date
        var calendar: Calendar
    }

    static func build(_ input: Input) -> JourneyStreakState {
        let copy = FormaProductCopy.Journey.Streaks.self
        let currentLogging = input.streakSummary.loggingStreak
        let longestLogging = StreakCalculator.longestLoggingStreak(
            in: input.maturityLogs,
            calendar: input.calendar
        )
        let proteinStreak = input.streakSummary.proteinStreak
        let waterStreak = input.streakSummary.hydrationStreak
        let trainingWeeks = input.isAppleHealthConnected
            ? StreakCalculator.trainingStreakWeeks(
                workoutDates: input.workoutDates,
                asOf: input.asOf,
                calendar: input.calendar
            )
            : nil
        let isTodayLogged = StreakCalculator.isLogged(
            on: input.asOf,
            in: input.maturityLogs,
            calendar: input.calendar
        )
        let streakThroughYesterday = StreakCalculator.loggingStreakEndingYesterday(
            logs: input.maturityLogs,
            asOf: input.asOf,
            calendar: input.calendar
        )

        let heroStreakChip = heroStreakChip(loggingStreak: currentLogging, copy: copy)
        let keepStreakAliveCopy = keepStreakAliveCopy(
            isTodayLogged: isTodayLogged,
            streakThroughYesterday: streakThroughYesterday,
            copy: copy
        )
        let weeklyConsistency = weeklyConsistencyCopy(
            currentLogging: currentLogging,
            longestLogging: longestLogging,
            proteinStreak: proteinStreak,
            waterStreak: waterStreak,
            trainingWeeks: trainingWeeks,
            copy: copy
        )
        let habitInsightStreakCopy = habitInsightStreakCopy(
            currentLogging: currentLogging,
            longestLogging: longestLogging,
            keepStreakAliveCopy: keepStreakAliveCopy,
            copy: copy
        )

        return JourneyStreakState(
            currentLoggingStreakDays: currentLogging,
            longestLoggingStreakDays: longestLogging,
            currentProteinStreakDays: proteinStreak,
            currentWaterStreakDays: waterStreak,
            currentTrainingStreakWeeks: trainingWeeks.flatMap { $0 > 0 ? $0 : nil },
            isTodayLogged: isTodayLogged,
            heroStreakChip: heroStreakChip,
            weeklyConsistencyHeadline: weeklyConsistency.headline,
            weeklyConsistencyDetail: weeklyConsistency.detail,
            habitInsightStreakCopy: habitInsightStreakCopy,
            keepStreakAliveCopy: keepStreakAliveCopy
        )
    }

    // MARK: - Copy

    private static func heroStreakChip(
        loggingStreak: Int,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> JourneyStreakChipState {
        guard loggingStreak > 0 else { return .hidden }
        return JourneyStreakChipState(
            isVisible: true,
            days: loggingStreak,
            label: copy.loggingStreak(days: loggingStreak)
        )
    }

    private static func keepStreakAliveCopy(
        isTodayLogged: Bool,
        streakThroughYesterday: Int,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> String? {
        guard !isTodayLogged, streakThroughYesterday > 0 else { return nil }
        return copy.keepStreakAlive(streakDays: streakThroughYesterday)
    }

    private static func weeklyConsistencyCopy(
        currentLogging: Int,
        longestLogging: Int,
        proteinStreak: Int,
        waterStreak: Int,
        trainingWeeks: Int?,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> (headline: String, detail: String?) {
        if currentLogging > 0 {
            var detailParts: [String] = []
            if longestLogging > currentLogging {
                detailParts.append(copy.longestLoggingStreak(days: longestLogging))
            }
            if proteinStreak > 0 {
                detailParts.append(copy.proteinStreak(days: proteinStreak))
            }
            if waterStreak > 0 {
                detailParts.append(copy.waterStreak(days: waterStreak))
            }
            if let trainingWeeks, trainingWeeks > 0 {
                detailParts.append(copy.trainingStreakWeeks(weeks: trainingWeeks))
            }
            return (
                copy.loggingStreak(days: currentLogging),
                detailParts.isEmpty ? nil : detailParts.joined(separator: " ")
            )
        }

        if longestLogging > 0 {
            return (copy.buildingConsistency, copy.longestLoggingStreak(days: longestLogging))
        }

        return (copy.buildingConsistency, nil)
    }

    private static func habitInsightStreakCopy(
        currentLogging: Int,
        longestLogging: Int,
        keepStreakAliveCopy: String?,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> String {
        if let keepStreakAliveCopy {
            return keepStreakAliveCopy
        }
        if currentLogging > 0 {
            return copy.loggingStreak(days: currentLogging)
        }
        if longestLogging > 0 {
            return copy.longestLoggingStreak(days: longestLogging)
        }
        return copy.buildingConsistency
    }
}
