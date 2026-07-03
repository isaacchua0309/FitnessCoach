//
//  WeeklyReviewPresentationPreviewData.swift
//  Fitness Coach
//
//  Forma — Preview fixtures for weekly review presentation states.
//

import Foundation

#if DEBUG
enum WeeklyReviewPresentationPreviewData {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static var strongWeekCard: WeeklyReviewCardState {
        WeeklyReviewPresentationBuilder.buildCard(from: strongReview, calendar: calendar)
    }

    static var strongWeekDetail: WeeklyReviewDetailState {
        WeeklyReviewPresentationBuilder.buildDetail(from: strongReview, calendar: calendar)!
    }

    static var emptyCard: WeeklyReviewCardState {
        WeeklyReviewPresentationBuilder.buildCard(from: nil, calendar: calendar)
    }

    static var sparseWeekDetail: WeeklyReviewDetailState {
        WeeklyReviewPresentationBuilder.buildDetail(from: sparseReview, calendar: calendar)!
    }

    private static var strongReview: WeeklyHealthReview {
        let weekEnd = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "You logged consistent workouts and kept protein on track most days.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 210,
                totalActiveCalories: 1_420,
                averageSteps: 8_200,
                totalSteps: 57_400,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 3,
                averageRecoveryScore: 68,
                lowRecoveryDays: 1,
                weightChangeKg: -0.3,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged", "Protein on target 5 days"],
            risks: ["Hydration dipped mid-week"],
            nextWeekFocus: ["Front-load water", "Keep one rest day lighter"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )
    }

    private static var sparseReview: WeeklyHealthReview {
        let weekEnd = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Building week",
            summary: "A lighter week with partial signals. Keep logging to strengthen next week's review.",
            stats: WeeklyStats(
                totalWorkouts: 1,
                totalWorkoutMinutes: 35,
                totalActiveCalories: 220,
                averageSteps: 5_400,
                totalSteps: 37_800,
                proteinHitDays: 2,
                calorieTargetHitDays: 2,
                waterHitDays: 1,
                averageRecoveryScore: nil,
                lowRecoveryDays: 2,
                weightChangeKg: nil,
                loggingConsistencyDays: 3
            ),
            wins: ["1 workout logged"],
            risks: ["Recovery was limited on 2 days"],
            nextWeekFocus: ["Add one more training day"],
            confidence: .low,
            missingSignals: [.recovery, .weight],
            generatedAt: weekEnd
        )
    }
}
#endif
