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
        let mealLoggingStreak = input.streakSummary.mealLoggingStreak
        let checkInStreak = input.streakSummary.checkInStreak
        let activityStreak = input.streakSummary.workoutStreak
        let longestCheckIn = StreakCalculator.longestLoggingStreak(
            in: input.maturityLogs,
            calendar: input.calendar
        )
        let longestMeal = StreakCalculator.longestMealLoggingStreak(
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
        let isTodayCheckedIn = StreakCalculator.isLogged(
            on: input.asOf,
            in: input.maturityLogs,
            calendar: input.calendar
        )
        let isTodayMealLogged = StreakCalculator.isMealLogged(
            on: input.asOf,
            in: input.maturityLogs,
            calendar: input.calendar
        )
        let streakThroughYesterday = StreakCalculator.loggingStreakEndingYesterday(
            logs: input.maturityLogs,
            asOf: input.asOf,
            calendar: input.calendar
        )

        let heroStreakChip = heroStreakChip(
            mealLoggingStreak: mealLoggingStreak,
            checkInStreak: checkInStreak,
            copy: copy
        )
        let keepStreakAliveCopy = keepStreakAliveCopy(
            isTodayCheckedIn: isTodayCheckedIn,
            streakThroughYesterday: streakThroughYesterday,
            copy: copy
        )
        let weeklyConsistency = weeklyConsistencyCopy(
            mealLoggingStreak: mealLoggingStreak,
            checkInStreak: checkInStreak,
            longestMeal: longestMeal,
            longestCheckIn: longestCheckIn,
            proteinStreak: proteinStreak,
            waterStreak: waterStreak,
            trainingWeeks: trainingWeeks,
            copy: copy
        )

        return JourneyStreakState(
            currentLoggingStreakDays: checkInStreak,
            currentMealLoggingStreakDays: mealLoggingStreak,
            currentCheckInStreakDays: checkInStreak,
            currentActivityStreakDays: activityStreak,
            longestLoggingStreakDays: longestCheckIn,
            longestMealLoggingStreakDays: longestMeal,
            currentProteinStreakDays: proteinStreak,
            currentWaterStreakDays: waterStreak,
            currentTrainingStreakWeeks: trainingWeeks.flatMap { $0 > 0 ? $0 : nil },
            isTodayLogged: isTodayCheckedIn,
            isTodayMealLogged: isTodayMealLogged,
            heroStreakChip: heroStreakChip,
            weeklyConsistencyHeadline: weeklyConsistency.headline,
            weeklyConsistencyDetail: weeklyConsistency.detail,
            keepStreakAliveCopy: keepStreakAliveCopy
        )
    }

    // MARK: - Copy

    private static func heroStreakChip(
        mealLoggingStreak: Int,
        checkInStreak: Int,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> JourneyStreakChipState {
        if mealLoggingStreak > 0 {
            return JourneyStreakChipState(
                isVisible: true,
                days: mealLoggingStreak,
                label: copy.mealLoggingStreak(days: mealLoggingStreak)
            )
        }
        guard checkInStreak > 0 else { return .hidden }
        return JourneyStreakChipState(
            isVisible: true,
            days: checkInStreak,
            label: copy.checkInStreak(days: checkInStreak)
        )
    }

    private static func keepStreakAliveCopy(
        isTodayCheckedIn: Bool,
        streakThroughYesterday: Int,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> String? {
        guard !isTodayCheckedIn, streakThroughYesterday > 0 else { return nil }
        return copy.keepStreakAlive(streakDays: streakThroughYesterday)
    }

    private static func weeklyConsistencyCopy(
        mealLoggingStreak: Int,
        checkInStreak: Int,
        longestMeal: Int,
        longestCheckIn: Int,
        proteinStreak: Int,
        waterStreak: Int,
        trainingWeeks: Int?,
        copy: FormaProductCopy.Journey.Streaks.Type
    ) -> (headline: String, detail: String?) {
        let headlineStreak = mealLoggingStreak > 0 ? mealLoggingStreak : checkInStreak
        let headlineLabel = mealLoggingStreak > 0
            ? copy.mealLoggingStreak(days: mealLoggingStreak)
            : copy.checkInStreak(days: checkInStreak)

        if headlineStreak > 0 {
            var detailParts: [String] = []
            let longest = mealLoggingStreak > 0 ? longestMeal : longestCheckIn
            if longest > headlineStreak {
                detailParts.append(
                    mealLoggingStreak > 0
                        ? copy.longestMealLoggingStreak(days: longest)
                        : copy.longestCheckInStreak(days: longest)
                )
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
            return (headlineLabel, detailParts.isEmpty ? nil : detailParts.joined(separator: " "))
        }

        if longestCheckIn > 0 {
            return (copy.buildingConsistency, copy.longestCheckInStreak(days: longestCheckIn))
        }

        return (copy.buildingConsistency, nil)
    }
}
