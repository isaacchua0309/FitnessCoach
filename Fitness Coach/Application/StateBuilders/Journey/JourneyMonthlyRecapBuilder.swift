//
//  JourneyMonthlyRecapBuilder.swift
//  Fitness Coach
//
//  Forma — Current-month progress story for Journey.
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

    static func build(_ input: Input) -> JourneyMonthlyRecapState {
        let copy = FormaProductCopy.Journey.MonthlyRecap.self
        let monthName = input.asOf.formatted(
            .dateTime.month(.wide).locale(input.calendar.locale ?? .current)
        )
        let sectionTitle = copy.sectionTitle(monthName: monthName)

        let foodLoggedDays = JourneyLogMetrics.foodLoggedDays(in: input.monthLogs)
        let isComplete = foodLoggedDays >= copy.minimumFoodLogDaysForRecap
        let isVisible = foodLoggedDays > 0 || isComplete

        guard isVisible else {
            return hiddenState(sectionTitle: sectionTitle)
        }

        guard isComplete else {
            return teaserState(
                copy: copy,
                sectionTitle: sectionTitle,
                teaserTitle: copy.teaserTitle(monthName: monthName),
                loggedDays: foodLoggedDays
            )
        }

        let monthWeights = input.allWeights.filter {
            input.calendar.isDate($0.date, equalTo: input.asOf, toGranularity: .month)
        }
        let monthWeightDelta = JourneyLogMetrics.weightDelta(in: monthWeights)

        let proteinEligible = input.monthLogs.filter { $0.targets.proteinTarget > 0 }
        let waterEligible = input.monthLogs.filter { $0.targets.waterTargetMl > 0 }
        let calorieEligible = input.monthLogs.filter { $0.targets.calorieTarget > 0 }

        let proteinAchieved = JourneyLogMetrics.proteinGoalDays(in: input.monthLogs)
        let waterAchieved = JourneyLogMetrics.waterGoalDays(in: input.monthLogs)
        let calorieAchieved = JourneyLogMetrics.calorieAdherenceDays(in: input.monthLogs)

        let proteinPercent = JourneyLogMetrics.adherencePercent(
            achieved: proteinAchieved,
            eligible: proteinEligible.count
        )
        let waterPercent = JourneyLogMetrics.adherencePercent(
            achieved: waterAchieved,
            eligible: waterEligible.count
        )
        let caloriePercent = JourneyLogMetrics.adherencePercent(
            achieved: calorieAchieved,
            eligible: calorieEligible.count
        )

        let workoutDays = input.isAppleHealthConnected ? input.monthHealthWorkoutCount : nil
        let bestStreakDays = bestLoggingStreak(in: input.monthLogs, calendar: input.calendar)
        let daysElapsed = daysElapsedInMonth(input: input)
        let grade = consistencyGrade(
            foodLoggedDays: foodLoggedDays,
            daysElapsed: daysElapsed,
            proteinPercent: proteinPercent,
            waterPercent: waterPercent,
            caloriePercent: caloriePercent,
            workoutDays: workoutDays,
            expectedTrainingDaysPerWeek: input.expectedTrainingDaysPerWeek,
            isAppleHealthConnected: input.isAppleHealthConnected
        )

        let rows = metricRows(
            copy: copy,
            foodLoggedDays: foodLoggedDays,
            proteinPercent: proteinPercent,
            waterPercent: waterPercent,
            caloriePercent: caloriePercent,
            workoutDays: workoutDays,
            monthWeightDelta: monthWeightDelta,
            bestStreakDays: bestStreakDays,
            grade: grade
        )

        let gradeLabel = copy.overallGrade(grade)
        let accessibilitySummary = ([sectionTitle] + rows.map { "\($0.title): \($0.value)" })
            .joined(separator: ". ")

        return JourneyMonthlyRecapState(
            isVisible: true,
            sectionTitle: sectionTitle,
            showsTeaser: false,
            teaserTitle: nil,
            teaserDetail: nil,
            overallGrade: mapGrade(grade),
            overallGradeLabel: gradeLabel,
            loggedDays: foodLoggedDays,
            monthWeightDeltaKg: monthWeightDelta,
            calorieAdherencePercent: caloriePercent,
            proteinAdherencePercent: proteinPercent,
            waterAdherencePercent: waterPercent,
            trainingSessions: workoutDays,
            bestStreakDays: bestStreakDays,
            rows: rows,
            accessibilitySummary: accessibilitySummary
        )
    }

    // MARK: - Visibility

    private static func hiddenState(sectionTitle: String) -> JourneyMonthlyRecapState {
        JourneyMonthlyRecapState(
            isVisible: false,
            sectionTitle: sectionTitle,
            showsTeaser: false,
            teaserTitle: nil,
            teaserDetail: nil,
            overallGrade: nil,
            overallGradeLabel: nil,
            loggedDays: 0,
            monthWeightDeltaKg: nil,
            calorieAdherencePercent: nil,
            proteinAdherencePercent: nil,
            waterAdherencePercent: nil,
            trainingSessions: nil,
            bestStreakDays: nil,
            rows: [],
            accessibilitySummary: sectionTitle
        )
    }

    private static func teaserState(
        copy: FormaProductCopy.Journey.MonthlyRecap.Type,
        sectionTitle: String,
        teaserTitle: String,
        loggedDays: Int
    ) -> JourneyMonthlyRecapState {
        let detail = copy.teaserDetail
        return JourneyMonthlyRecapState(
            isVisible: true,
            sectionTitle: sectionTitle,
            showsTeaser: true,
            teaserTitle: teaserTitle,
            teaserDetail: detail,
            overallGrade: nil,
            overallGradeLabel: nil,
            loggedDays: loggedDays,
            monthWeightDeltaKg: nil,
            calorieAdherencePercent: nil,
            proteinAdherencePercent: nil,
            waterAdherencePercent: nil,
            trainingSessions: nil,
            bestStreakDays: nil,
            rows: [],
            accessibilitySummary: "\(sectionTitle). \(teaserTitle) \(detail)"
        )
    }

    // MARK: - Rows

    private static func metricRows(
        copy: FormaProductCopy.Journey.MonthlyRecap.Type,
        foodLoggedDays: Int,
        proteinPercent: Double?,
        waterPercent: Double?,
        caloriePercent: Double?,
        workoutDays: Int?,
        monthWeightDelta: Double?,
        bestStreakDays: Int?,
        grade: FormaProductCopy.Journey.MonthlyRecap.Grade
    ) -> [JourneyMonthlyRecapMetricRow] {
        var rows: [JourneyMonthlyRecapMetricRow] = []

        if foodLoggedDays > 0 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "meals",
                    title: copy.mealsLoggedTitle,
                    value: copy.mealsLoggedValue(foodLoggedDays)
                )
            )
        }

        if let proteinPercent, proteinPercent > 0 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "protein",
                    title: copy.proteinTitle,
                    value: copy.hitRatePercent(Int((proteinPercent * 100).rounded()))
                )
            )
        }

        if let waterPercent, waterPercent > 0 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "water",
                    title: copy.waterTitle,
                    value: copy.hitRatePercent(Int((waterPercent * 100).rounded()))
                )
            )
        }

        if let workoutDays, workoutDays > 0 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "workouts",
                    title: copy.workoutDaysTitle,
                    value: copy.workoutDays(workoutDays)
                )
            )
        }

        if let caloriePercent, caloriePercent > 0 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "calories",
                    title: copy.caloriesTitle,
                    value: copy.hitRatePercent(Int((caloriePercent * 100).rounded()))
                )
            )
        }

        if let monthWeightDelta, abs(monthWeightDelta) >= 0.1 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "weight",
                    title: copy.weightTitle,
                    value: copy.weightChange(deltaKg: monthWeightDelta)
                )
            )
        }

        if let bestStreakDays, bestStreakDays > 1 {
            rows.append(
                JourneyMonthlyRecapMetricRow(
                    id: "streak",
                    title: copy.bestStreakTitle,
                    value: copy.bestStreak(days: bestStreakDays)
                )
            )
        }

        rows.append(
            JourneyMonthlyRecapMetricRow(
                id: "overall",
                title: copy.overallTitle,
                value: copy.overallGrade(grade)
            )
        )

        return rows
    }

    // MARK: - Grade

    private static func consistencyGrade(
        foodLoggedDays: Int,
        daysElapsed: Int,
        proteinPercent: Double?,
        waterPercent: Double?,
        caloriePercent: Double?,
        workoutDays: Int?,
        expectedTrainingDaysPerWeek: Int,
        isAppleHealthConnected: Bool
    ) -> FormaProductCopy.Journey.MonthlyRecap.Grade {
        var rates: [Double] = []

        if daysElapsed > 0 {
            rates.append(Double(foodLoggedDays) / Double(daysElapsed))
        }
        if let proteinPercent { rates.append(proteinPercent) }
        if let waterPercent { rates.append(waterPercent) }
        if let caloriePercent { rates.append(caloriePercent) }

        if isAppleHealthConnected, let workoutDays, expectedTrainingDaysPerWeek > 0 {
            let expected = max(
                1,
                Int(ceil(Double(expectedTrainingDaysPerWeek) * Double(daysElapsed) / 7.0))
            )
            rates.append(Double(workoutDays) / Double(expected))
        }

        guard !rates.isEmpty else { return .starting }

        let average = rates.reduce(0, +) / Double(rates.count)
        let score = Int((average * 100).rounded())

        switch score {
        case 80...: return .excellent
        case 60..<80: return .strong
        case 40..<60: return .consistent
        case 20..<40: return .building
        default: return .starting
        }
    }

    private static func mapGrade(
        _ grade: FormaProductCopy.Journey.MonthlyRecap.Grade
    ) -> JourneyMonthlyRecapGrade {
        switch grade {
        case .starting: return .starting
        case .building: return .building
        case .consistent: return .consistent
        case .strong: return .strong
        case .excellent: return .excellent
        }
    }

    // MARK: - Helpers

    private static func bestLoggingStreak(in logs: [DailyLog], calendar: Calendar) -> Int? {
        let streak = StreakCalculator.longestLoggingStreak(in: logs, calendar: calendar)
        return streak > 0 ? streak : nil
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
