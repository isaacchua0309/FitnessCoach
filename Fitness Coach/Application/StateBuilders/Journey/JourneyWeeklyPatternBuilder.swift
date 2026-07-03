//
//  JourneyWeeklyPatternBuilder.swift
//  Fitness Coach
//
//  Forma — Streak-based weekly habit reflection for Journey.
//

import Foundation

enum JourneyWeeklyPatternBuilder {

    struct Input: Equatable {
        var weekLogs: [DailyLog]
        var weekWeights: [WeightEntry]
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var weeklyTraining: JourneyWeeklyTrainingStatus
        var expectedTrainingDays: Int
        var streaks: JourneyStreakState
        var streakSummary: StreakSummary
        var weeklyReview: JourneyWeeklyReviewState
        var asOf: Date
        var calendar: Calendar
    }

    static func build(_ input: Input) -> JourneyWeeklyHabitState {
        let copy = FormaProductCopy.Journey.WeeklyReview.self
        let weekDays = JourneyLogMetrics.rollingWeekDayStarts(asOf: input.asOf, calendar: input.calendar)
        let logsByDay = JourneyLogMetrics.logByDay(in: input.weekLogs, calendar: input.calendar)
        let weightDays = JourneyLogMetrics.weightDays(
            in: input.weekLogs,
            weights: input.weekWeights,
            calendar: input.calendar
        )

        let foodDays = JourneyLogMetrics.uniqueFoodLoggedDays(in: input.weekLogs, calendar: input.calendar)
        let proteinDays = JourneyLogMetrics.uniqueProteinGoalDays(in: input.weekLogs, calendar: input.calendar)
        let waterDays = JourneyLogMetrics.uniqueWaterGoalDays(in: input.weekLogs, calendar: input.calendar)
        let calorieDays = JourneyLogMetrics.uniqueCalorieAdherenceDays(in: input.weekLogs, calendar: input.calendar)
        let weightLogDays = JourneyLogMetrics.weightLoggedDays(
            in: input.weekLogs,
            weights: input.weekWeights,
            calendar: input.calendar
        )
        let workoutDays = JourneyLogMetrics.workoutDays(
            in: input.weekLogs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            calendar: input.calendar
        )

        let hasWeeklyActivity = foodDays > 0
            || proteinDays > 0
            || waterDays > 0
            || calorieDays > 0
            || weightLogDays > 0
            || workoutDays > 0

        guard hasWeeklyActivity else {
            return JourneyWeeklyHabitState(
                isVisible: true,
                sectionTitle: copy.sectionTitle,
                showsHabitRows: false,
                emptyMessage: copy.emptyState,
                habits: [],
                training: input.weeklyTraining,
                accessibilitySummary: "\(copy.sectionTitle). \(copy.emptyState)",
                weeklyReviewState: input.weeklyReview
            )
        }

        var habits: [JourneyWeeklyHabitRowState] = [
            makeHabitRow(
                id: "food",
                title: copy.foodTitle,
                achieved: foodDays,
                total: JourneyLogMetrics.weekDayCount,
                streakDays: input.streaks.currentLoggingStreakDays,
                dayCells: dayCells(for: weekDays, calendar: input.calendar, logsByDay: logsByDay, weightDays: weightDays, healthWorkouts: input.healthWorkoutDayStarts) {
                    JourneyLogMetrics.isFoodLogged(on: $0, logsByDay: logsByDay)
                },
                copy: copy
            ),
            makeHabitRow(
                id: "protein",
                title: copy.proteinTitle,
                achieved: proteinDays,
                total: JourneyLogMetrics.weekDayCount,
                streakDays: input.streaks.currentProteinStreakDays,
                dayCells: dayCells(for: weekDays, calendar: input.calendar, logsByDay: logsByDay, weightDays: weightDays, healthWorkouts: input.healthWorkoutDayStarts) {
                    JourneyLogMetrics.isProteinGoalMet(on: $0, logsByDay: logsByDay)
                },
                copy: copy
            ),
            makeHabitRow(
                id: "water",
                title: copy.waterTitle,
                achieved: waterDays,
                total: JourneyLogMetrics.weekDayCount,
                streakDays: input.streaks.currentWaterStreakDays,
                dayCells: dayCells(for: weekDays, calendar: input.calendar, logsByDay: logsByDay, weightDays: weightDays, healthWorkouts: input.healthWorkoutDayStarts) {
                    JourneyLogMetrics.isWaterGoalMet(on: $0, logsByDay: logsByDay)
                },
                copy: copy
            )
        ]

        if let trainingHabit = trainingHabit(
            input: input,
            weekDays: weekDays,
            logsByDay: logsByDay,
            weightDays: weightDays,
            workoutDays: workoutDays,
            copy: copy
        ) {
            habits.append(trainingHabit)
        }

        habits.append(
            makeHabitRow(
                id: "calories",
                title: copy.calorieTitle,
                achieved: calorieDays,
                total: JourneyLogMetrics.weekDayCount,
                streakDays: StreakCalculator.calorieStreak(
                    logs: input.maturityLogs,
                    asOf: input.asOf,
                    calendar: input.calendar
                ),
                dayCells: dayCells(for: weekDays, calendar: input.calendar, logsByDay: logsByDay, weightDays: weightDays, healthWorkouts: input.healthWorkoutDayStarts) {
                    JourneyLogMetrics.isCalorieGoalMet(on: $0, logsByDay: logsByDay)
                },
                copy: copy
            )
        )

        habits.append(
            makeHabitRow(
                id: "weight",
                title: copy.weightTitle,
                achieved: weightLogDays,
                total: JourneyLogMetrics.weekDayCount,
                streakDays: StreakCalculator.weightLogStreak(
                    logs: input.maturityLogs,
                    weights: input.allWeights,
                    asOf: input.asOf,
                    calendar: input.calendar
                ),
                dayCells: dayCells(for: weekDays, calendar: input.calendar, logsByDay: logsByDay, weightDays: weightDays, healthWorkouts: input.healthWorkoutDayStarts) {
                    JourneyLogMetrics.isWeightLogged(on: $0, logsByDay: logsByDay, weightDays: weightDays)
                },
                copy: copy
            )
        )

        let accessibilitySummary = [
            copy.sectionTitle,
            habits.map { "\($0.title), \($0.weeklyCountLabel)" }.joined(separator: ". ")
        ].joined(separator: ". ")

        return JourneyWeeklyHabitState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            showsHabitRows: true,
            emptyMessage: nil,
            habits: habits,
            training: input.weeklyTraining,
            accessibilitySummary: accessibilitySummary,
            weeklyReviewState: input.weeklyReview
        )
    }

    // MARK: - Rows

    private static func makeHabitRow(
        id: String,
        title: String,
        achieved: Int,
        total: Int,
        streakDays: Int,
        dayCells: [Bool],
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyHabitRowState {
        let streakLabel = streakDays >= 2 ? copy.streakLabel(days: streakDays) : nil
        let supportiveCopy = supportiveCopy(
            achieved: achieved,
            hasStreakLabel: streakLabel != nil,
            copy: copy
        )

        return JourneyWeeklyHabitRowState(
            id: id,
            title: title,
            weeklyCountLabel: copy.weekDayCount(current: achieved, total: total),
            streakLabel: streakLabel,
            supportiveCopy: supportiveCopy,
            dayCells: dayCells
        )
    }

    private static func trainingHabit(
        input: Input,
        weekDays: [Date],
        logsByDay: [Date: DailyLog],
        weightDays: Set<Date>,
        workoutDays: Int,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> JourneyWeeklyHabitRowState? {
        switch input.weeklyTraining {
        case .hidden:
            return nil
        case .locked:
            return JourneyWeeklyHabitRowState(
                id: "training",
                title: copy.trainingTitle,
                weeklyCountLabel: copy.trainingConnectAppleHealth,
                streakLabel: nil,
                supportiveCopy: nil,
                dayCells: Array(repeating: false, count: JourneyLogMetrics.weekDayCount),
                showsDayProgress: false
            )
        case .connectedEmpty, .connected:
            let total = input.expectedTrainingDays > 0
                ? input.expectedTrainingDays
                : JourneyLogMetrics.weekDayCount
            return makeHabitRow(
                id: "training",
                title: copy.trainingTitle,
                achieved: workoutDays,
                total: total,
                streakDays: input.streakSummary.workoutStreak,
                dayCells: dayCells(for: weekDays, calendar: input.calendar, logsByDay: logsByDay, weightDays: weightDays, healthWorkouts: input.healthWorkoutDayStarts) {
                    JourneyLogMetrics.isWorkoutLogged(
                        on: $0,
                        logsByDay: logsByDay,
                        healthWorkoutDayStarts: input.healthWorkoutDayStarts
                    )
                },
                copy: copy
            )
        }
    }

    private static func supportiveCopy(
        achieved: Int,
        hasStreakLabel: Bool,
        copy: FormaProductCopy.Journey.WeeklyReview.Type
    ) -> String? {
        guard !hasStreakLabel, achieved > 0, achieved < 3 else { return nil }
        return copy.oneMoreDayMomentum
    }

    private static func dayCells(
        for weekDays: [Date],
        calendar: Calendar,
        logsByDay: [Date: DailyLog],
        weightDays: Set<Date>,
        healthWorkouts: Set<Date>,
        isMet: (Date) -> Bool
    ) -> [Bool] {
        weekDays.map { day in
            let normalized = calendar.startOfDay(for: day)
            return isMet(normalized)
        }
    }
}
