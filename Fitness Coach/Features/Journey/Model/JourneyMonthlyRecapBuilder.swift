//
//  JourneyMonthlyRecapBuilder.swift
//  Fitness Coach
//
//  Forma — Current-month summary for Journey.
//

import Foundation

enum JourneyMonthlyRecapBuilder {

    struct Input: Equatable {
        var monthLogs: [DailyLog]
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var healthWorkoutDayStarts: Set<Date>
        var monthHealthWorkoutCount: Int
        var goalDirection: JourneyGoalDirection
        var isAppleHealthConnected: Bool
        var expectedTrainingDaysPerWeek: Int
        var asOf: Date
        var calendar: Calendar
    }

    private static let minimumFoodLogDaysForCompleteRecap = 3

    static func build(_ input: Input) -> JourneyMonthlyRecapState {
        let copy = FormaProductCopy.Journey.MonthlyRecap.self
        let monthName = input.asOf.formatted(
            .dateTime.month(.wide).locale(input.calendar.locale ?? .current)
        )
        let monthLabel = input.asOf.formatted(.dateTime.month(.wide).year())
        let sectionTitle = copy.sectionTitle(monthName: monthName)

        let monthWeights = input.allWeights.filter {
            input.calendar.isDate($0.date, equalTo: input.asOf, toGranularity: .month)
        }
        let monthWeightDelta = JourneyLogMetrics.weightDelta(in: monthWeights)

        let proteinEligible = input.monthLogs.filter { $0.targets.proteinTarget > 0 }
        let waterEligible = input.monthLogs.filter { $0.targets.waterTargetMl > 0 }
        let calorieEligible = input.monthLogs.filter { $0.targets.calorieTarget > 0 }

        let proteinPercent = JourneyLogMetrics.adherencePercent(
            achieved: JourneyLogMetrics.proteinGoalDays(in: input.monthLogs),
            eligible: proteinEligible.count
        )
        let waterPercent = JourneyLogMetrics.adherencePercent(
            achieved: JourneyLogMetrics.waterGoalDays(in: input.monthLogs),
            eligible: waterEligible.count
        )
        let caloriePercent = JourneyLogMetrics.adherencePercent(
            achieved: JourneyLogMetrics.calorieAdherenceDays(in: input.monthLogs),
            eligible: calorieEligible.count
        )

        let foodLoggedDays = JourneyLogMetrics.foodLoggedDays(in: input.monthLogs)
        let isComplete = foodLoggedDays >= minimumFoodLogDaysForCompleteRecap

        let calendar = JourneyDashboardBuilder.consistencyCalendar(
            logs: input.maturityLogs,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            weights: input.allWeights,
            month: input.asOf,
            calendar: input.calendar
        )

        let bestHabit = bestHabitKind(input: input, daysElapsedInMonth: daysElapsedInMonth(input: input))
        let bestHabitCopy = bestHabit.map { copy.bestHabit(for: $0) }

        let showsTrainingRow = input.isAppleHealthConnected
        let trainingSessions = showsTrainingRow ? input.monthHealthWorkoutCount : nil

        var rows = metricRows(
            copy: copy,
            monthWeightDelta: monthWeightDelta,
            goalDirection: input.goalDirection,
            caloriePercent: caloriePercent,
            proteinPercent: proteinPercent,
            waterPercent: waterPercent,
            trainingSessions: trainingSessions,
            showsTrainingRow: showsTrainingRow,
            foodLoggedDays: foodLoggedDays,
            isComplete: isComplete
        )

        let summaryCopy = summaryCopy(
            copy: copy,
            isComplete: isComplete,
            foodLoggedDays: foodLoggedDays,
            bestHabitCopy: bestHabitCopy
        )

        return JourneyMonthlyRecapState(
            sectionTitle: sectionTitle,
            isComplete: isComplete,
            buildingMessage: isComplete ? nil : copy.buildingBody,
            monthLabel: monthLabel,
            monthWeightDeltaKg: monthWeightDelta,
            calorieAdherencePercent: caloriePercent,
            proteinAdherencePercent: proteinPercent,
            waterAdherencePercent: waterPercent,
            trainingSessions: trainingSessions,
            showsTrainingRow: showsTrainingRow,
            loggedDays: foodLoggedDays,
            bestHabitCopy: isComplete ? bestHabitCopy : nil,
            summaryCopy: summaryCopy,
            rows: rows,
            calendar: calendar
        )
    }

    // MARK: - Rows

    private static func metricRows(
        copy: FormaProductCopy.Journey.MonthlyRecap.Type,
        monthWeightDelta: Double?,
        goalDirection: JourneyGoalDirection,
        caloriePercent: Double?,
        proteinPercent: Double?,
        waterPercent: Double?,
        trainingSessions: Int?,
        showsTrainingRow: Bool,
        foodLoggedDays: Int,
        isComplete: Bool
    ) -> [JourneyMonthlyRecapMetricRow] {
        var rows: [JourneyMonthlyRecapMetricRow] = []

        if isComplete {
            if let monthWeightDelta, abs(monthWeightDelta) >= 0.1 {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "weight",
                        title: copy.weightTitle,
                        value: copy.weightDelta(deltaKg: monthWeightDelta, direction: goalDirection)
                    )
                )
            }
            if let caloriePercent {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "calories",
                        title: copy.caloriesTitle,
                        value: copy.calorieAdherence(percent: Int((caloriePercent * 100).rounded()))
                    )
                )
            }
            if let proteinPercent {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "protein",
                        title: copy.proteinTitle,
                        value: copy.adherencePercent(Int((proteinPercent * 100).rounded()))
                    )
                )
            }
            if let waterPercent {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "water",
                        title: copy.waterTitle,
                        value: copy.adherencePercent(Int((waterPercent * 100).rounded()))
                    )
                )
            }
            if showsTrainingRow, let trainingSessions {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "training",
                        title: copy.trainingTitle,
                        value: copy.trainingSessions(trainingSessions)
                    )
                )
            }
        } else {
            if foodLoggedDays > 0 {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "logged-days",
                        title: copy.loggedDaysTitle,
                        value: copy.loggedDaysValue(foodLoggedDays)
                    )
                )
            }
            if let proteinPercent {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "protein",
                        title: copy.proteinTitle,
                        value: copy.adherencePercent(Int((proteinPercent * 100).rounded()))
                    )
                )
            }
            if let waterPercent {
                rows.append(
                    JourneyMonthlyRecapMetricRow(
                        id: "water",
                        title: copy.waterTitle,
                        value: copy.adherencePercent(Int((waterPercent * 100).rounded()))
                    )
                )
            }
        }

        return rows
    }

    // MARK: - Summary

    private static func summaryCopy(
        copy: FormaProductCopy.Journey.MonthlyRecap.Type,
        isComplete: Bool,
        foodLoggedDays: Int,
        bestHabitCopy: String?
    ) -> String {
        if !isComplete {
            if foodLoggedDays > 0 {
                return copy.loggedDaysSummary(foodLoggedDays)
            }
            return ""
        }

        var parts = [copy.loggedDaysSummary(foodLoggedDays)]
        if let bestHabitCopy {
            parts.append(bestHabitCopy)
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Best habit

    private static func bestHabitKind(
        input: Input,
        daysElapsedInMonth: Int
    ) -> JourneyHabitKind? {
        let monthLogs = input.monthLogs
        guard !monthLogs.isEmpty, daysElapsedInMonth > 0 else { return nil }

        var scores: [(JourneyHabitKind, Int)] = []

        let foodDays = JourneyLogMetrics.foodLoggedDays(in: monthLogs)
        scores.append((
            .foodLogging,
            percentScore(achieved: foodDays, eligible: daysElapsedInMonth)
        ))

        let proteinEligible = monthLogs.filter { $0.targets.proteinTarget > 0 }
        if !proteinEligible.isEmpty {
            scores.append((
                .protein,
                percentScore(
                    achieved: JourneyLogMetrics.proteinGoalDays(in: monthLogs),
                    eligible: proteinEligible.count
                )
            ))
        }

        let waterEligible = monthLogs.filter { $0.targets.waterTargetMl > 0 }
        if !waterEligible.isEmpty {
            scores.append((
                .water,
                percentScore(
                    achieved: JourneyLogMetrics.waterGoalDays(in: monthLogs),
                    eligible: waterEligible.count
                )
            ))
        }

        let calorieEligible = monthLogs.filter { $0.targets.calorieTarget > 0 }
        if !calorieEligible.isEmpty {
            scores.append((
                .calorieAdherence,
                percentScore(
                    achieved: JourneyLogMetrics.calorieAdherenceDays(in: monthLogs),
                    eligible: calorieEligible.count
                )
            ))
        }

        if input.isAppleHealthConnected, input.expectedTrainingDaysPerWeek > 0 {
            let expected = max(
                1,
                Int(ceil(Double(input.expectedTrainingDaysPerWeek) * Double(daysElapsedInMonth) / 7.0))
            )
            scores.append((
                .training,
                percentScore(achieved: input.monthHealthWorkoutCount, eligible: expected)
            ))
        }

        return scores.max { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return habitOrder(lhs.0) > habitOrder(rhs.0)
        }?.0
    }

    private static func percentScore(achieved: Int, eligible: Int) -> Int {
        guard eligible > 0 else { return 0 }
        return Int((Double(achieved) / Double(eligible) * 100).rounded())
    }

    private static func habitOrder(_ kind: JourneyHabitKind) -> Int {
        switch kind {
        case .foodLogging: return 0
        case .protein: return 1
        case .water: return 2
        case .calorieAdherence: return 3
        case .training: return 4
        case .weightLogging: return 5
        case .weekendLogging: return 6
        }
    }

    private static func daysElapsedInMonth(input: Input) -> Int {
        guard let monthInterval = input.calendar.dateInterval(of: .month, for: input.asOf) else {
            return 1
        }
        let monthStart = input.calendar.startOfDay(for: monthInterval.start)
        let asOfDay = input.calendar.startOfDay(for: input.asOf)
        let days = input.calendar.dateComponents([.day], from: monthStart, to: asOfDay).day ?? 0
        return max(days + 1, 1)
    }
}
