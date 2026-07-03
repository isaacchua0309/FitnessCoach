//
//  PlanEditHeroStateBuilder.swift
//  Fitness Coach
//
//  Forma — Live hero summary for the Edit Plan shell.
//

import Foundation

struct PlanEditHeroState: Equatable, Sendable {
    let motivationalLine: String
    let goalLabel: String
    let goalValue: String
    let currentWeightLabel: String
    let currentWeight: String
    let targetWeightLabel: String
    let targetWeight: String
    let totalChangeLine: String?
    let estimatedFinishLine: String?
    let accessibilitySummary: String
}

enum PlanEditHeroStateBuilder {

    struct Input: Equatable, Sendable {
        var goalType: PlanGoalType
        var currentWeightKg: Double?
        var goalWeightKg: Double?
        var weeklyPaceKg: Double?
        var goalDatePace: Date?
        var referenceDate: Date
        var calendar: Calendar
    }

    static func build(input: Input) -> PlanEditHeroState {
        let copy = FormaProductCopy.PlanEditHero.self
        let motivationalLine = motivationalLine(for: input.goalType)
        let currentWeight = formattedWeight(input.currentWeightKg)
        let targetWeight = formattedWeight(input.goalWeightKg)
        let totalChangeLine = totalChangeLine(
            goalType: input.goalType,
            currentKg: input.currentWeightKg,
            goalKg: input.goalWeightKg
        )
        let estimatedFinishLine = estimatedFinishLine(
            goalType: input.goalType,
            currentKg: input.currentWeightKg,
            goalKg: input.goalWeightKg,
            weeklyPaceKg: input.weeklyPaceKg,
            goalDatePace: input.goalDatePace,
            referenceDate: input.referenceDate,
            calendar: input.calendar
        )

        let state = PlanEditHeroState(
            motivationalLine: motivationalLine,
            goalLabel: copy.goalLabel,
            goalValue: input.goalType.rawValue,
            currentWeightLabel: copy.currentWeightLabel,
            currentWeight: currentWeight,
            targetWeightLabel: copy.targetWeightLabel,
            targetWeight: targetWeight,
            totalChangeLine: totalChangeLine,
            estimatedFinishLine: estimatedFinishLine,
            accessibilitySummary: accessibilitySummary(
                motivationalLine: motivationalLine,
                goalLabel: copy.goalLabel,
                goalValue: input.goalType.rawValue,
                currentWeightLabel: copy.currentWeightLabel,
                currentWeight: currentWeight,
                targetWeightLabel: copy.targetWeightLabel,
                targetWeight: targetWeight,
                totalChangeLine: totalChangeLine,
                estimatedFinishLine: estimatedFinishLine
            )
        )

        return state
    }

    private static func motivationalLine(for goalType: PlanGoalType) -> String {
        switch goalType {
        case .loseFat:
            return FormaProductCopy.PlanEditHero.motivationalFatLoss
        case .maintain:
            return FormaProductCopy.PlanEditHero.motivationalMaintenance
        case .gainMuscle:
            return FormaProductCopy.PlanEditHero.motivationalMuscleGain
        }
    }

    private static func totalChangeLine(
        goalType: PlanGoalType,
        currentKg: Double?,
        goalKg: Double?
    ) -> String? {
        guard let currentKg, let goalKg else { return nil }

        switch goalType {
        case .maintain:
            return FormaProductCopy.PlanEditHero.maintainingTarget
        case .loseFat:
            let delta = currentKg - goalKg
            guard delta > 0.1 else { return FormaProductCopy.PlanEditHero.maintainingTarget }
            return FormaProductCopy.PlanEditHero.totalChangeToTarget(formatKg(delta))
        case .gainMuscle:
            let delta = goalKg - currentKg
            guard delta > 0.1 else { return FormaProductCopy.PlanEditHero.maintainingTarget }
            return FormaProductCopy.PlanEditHero.totalChangeToTarget(formatKg(delta))
        }
    }

    private static func estimatedFinishLine(
        goalType: PlanGoalType,
        currentKg: Double?,
        goalKg: Double?,
        weeklyPaceKg: Double?,
        goalDatePace: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> String? {
        if let goalDatePace, goalDatePace > referenceDate {
            return FormaProductCopy.PlanEditHero.estimatedFinish(
                formattedMonthYear(goalDatePace, calendar: calendar)
            )
        }

        guard goalType == .loseFat,
              let currentKg,
              let goalKg,
              let weeklyPaceKg,
              weeklyPaceKg > 0
        else { return nil }

        let remaining = currentKg - goalKg
        guard remaining > 0.1 else { return nil }

        let weeks = remaining / weeklyPaceKg
        guard weeks > 0, weeks <= 520 else { return nil }

        let days = Int((weeks * 7.0).rounded(.up))
        guard let finishDate = calendar.date(byAdding: .day, value: days, to: referenceDate) else {
            return nil
        }

        return FormaProductCopy.PlanEditHero.estimatedFinish(
            formattedMonthYear(finishDate, calendar: calendar)
        )
    }

    private static func accessibilitySummary(
        motivationalLine: String,
        goalLabel: String,
        goalValue: String,
        currentWeightLabel: String,
        currentWeight: String,
        targetWeightLabel: String,
        targetWeight: String,
        totalChangeLine: String?,
        estimatedFinishLine: String?
    ) -> String {
        var parts = [
            motivationalLine,
            "\(goalLabel), \(goalValue)",
            "\(currentWeightLabel), \(currentWeight)",
            "\(targetWeightLabel), \(targetWeight)"
        ]
        if let totalChangeLine {
            parts.append(totalChangeLine)
        }
        if let estimatedFinishLine {
            parts.append(estimatedFinishLine)
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Formatting

    private static func formattedWeight(_ value: Double?) -> String {
        guard let value, value > 0 else {
            return FormaProductCopy.PlanEditHero.weightUnavailable
        }
        return PlanFormatter.kg(value)
    }

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }

    private static func formattedMonthYear(_ date: Date, calendar: Calendar) -> String {
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
            .month(.wide)
            .year()
            .locale(.autoupdatingCurrent)
        format.calendar = calendar
        return date.formatted(format)
    }
}
