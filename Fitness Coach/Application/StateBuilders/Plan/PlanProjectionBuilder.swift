//
//  PlanProjectionBuilder.swift
//  Fitness Coach
//
//  Forma — Builds PlanProjection from form inputs and the calculation engine.
//

import Foundation

struct PlanProjectionInput: Equatable, Sendable {
    var goalType: PlanGoalType
    var formState: PlanFormState
    var caloriePreview: CalorieTargetResult?
    var goalDatePaceOverride: Date? = nil
    var referenceDate: Date
    var calendar: Calendar
}

enum PlanProjectionBuilder {

    private static let maxEstimatedWeeks = 520

    static func build(
        formState: PlanFormState,
        goalType: PlanGoalType,
        caloriePreview: CalorieTargetResult? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PlanProjection {
        build(
            input: PlanProjectionInput(
                goalType: goalType,
                formState: formState,
                caloriePreview: caloriePreview,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    static func build(input: PlanProjectionInput) -> PlanProjection {
        let direction = resolvedDirection(
            goalType: input.goalType,
            currentKg: parsedPositive(input.formState.currentWeightKgText),
            goalKg: parsedPositive(input.formState.goalWeightKgText)
        )
        let currentKg = parsedPositive(input.formState.currentWeightKgText)
        let goalKg = parsedPositive(input.formState.goalWeightKgText)
        let weightDelta = weightToLoseOrGainKg(
            direction: direction,
            currentKg: currentKg,
            goalKg: goalKg
        )

        let pacePreview = pacePreview(
            formState: input.formState,
            currentKg: currentKg,
            goalKg: goalKg,
            referenceDate: input.referenceDate
        )
        let goalDatePace = resolvedGoalDatePace(formState: input.formState)
            ?? input.goalDatePaceOverride

        let engineResult = try? fullCalculationResult(
            formState: input.formState,
            referenceDate: input.referenceDate
        )

        let timeline = timelineMetrics(
            direction: direction,
            currentKg: currentKg,
            goalKg: goalKg,
            weeklyRateKg: resolvedWeeklyRateKg(
                engineResult: engineResult,
                pacePreview: pacePreview,
                caloriePreview: input.caloriePreview
            ),
            goalDatePace: goalDatePace,
            referenceDate: input.referenceDate,
            calendar: input.calendar
        )

        let energy = energyMetrics(
            direction: direction,
            engineResult: engineResult,
            caloriePreview: input.caloriePreview,
            pacePreview: pacePreview
        )

        let targets = targetMetrics(
            engineResult: engineResult,
            caloriePreview: input.caloriePreview,
            formState: input.formState
        )

        let difficulty = difficultyMetrics(
            goalType: input.goalType,
            direction: direction,
            paceChoice: input.formState.weightLossPaceChoice,
            engineResult: engineResult,
            pacePreview: pacePreview
        )

        let isComplete = engineResult != nil
        let validationMessage = isComplete ? nil : FormaProductCopy.PlanProjection.incompleteCalculation

        return PlanProjection(
            goalLabel: goalLabel(for: input.goalType),
            goalDirection: direction,
            currentWeightDisplay: formattedWeight(currentKg),
            targetWeightDisplay: formattedWeight(goalKg),
            weightToLoseOrGainKg: weightDelta,
            weightChangeLabel: weightChangeLabel(
                direction: direction,
                deltaKg: weightDelta
            ),
            weeklyRateKg: timeline.weeklyRateKg,
            monthlyRateKg: timeline.monthlyRateKg,
            estimatedWeeks: timeline.estimatedWeeks,
            estimatedCompletionDate: timeline.estimatedCompletionDate,
            estimatedCompletionLabel: timeline.estimatedCompletionLabel,
            dailyDeficitOrSurplusKcal: energy.dailyBalanceKcal,
            dailyDeficitOrSurplusLabel: energy.dailyBalanceLabel,
            maintenanceCalories: energy.maintenanceCalories,
            targetCalories: targets.calories,
            proteinTargetG: targets.proteinG,
            carbTargetG: targets.carbG,
            fatTargetG: targets.fatG,
            waterTargetMl: targets.waterMl,
            difficultyLabel: difficulty.label,
            difficultyDescription: difficulty.description,
            adherenceEstimate: difficulty.adherence,
            recoveryImpact: difficulty.recovery,
            hungerImpact: difficulty.hunger,
            isCalculationComplete: isComplete,
            validationMessage: validationMessage
        )
    }

    // MARK: - Calculation bridge

    private static func fullCalculationResult(
        formState: PlanFormState,
        referenceDate: Date
    ) throws -> PlanCalculationResult {
        let calorieInput = try formState.makeCalorieTargetInput()
        let planInput = PlanCalculationBridge.planInput(
            from: calorieInput,
            referenceDate: referenceDate
        )
        return try FormaCalculationEngine.calculate(planInput)
    }

    private static func resolvedGoalDatePace(formState: PlanFormState) -> Date? {
        guard let pace = try? formState.resolvedWeightLossPace(),
              case .goalDate(let date) = pace else {
            return nil
        }
        return date
    }

    private static func pacePreview(
        formState: PlanFormState,
        currentKg: Double?,
        goalKg: Double?,
        referenceDate: Date
    ) -> WeightLossPacePreviewModel {
        guard let currentKg, let goalKg else {
            return .empty
        }
        return WeightLossPacePreviewBuilder.build(
            choice: formState.weightLossPaceChoice,
            advancedDraft: formState.advancedPaceDraft,
            weightKg: currentKg,
            goalWeightKg: goalKg,
            referenceDate: referenceDate
        )
    }

    // MARK: - Weight journey

    private static func resolvedDirection(
        goalType: PlanGoalType,
        currentKg: Double?,
        goalKg: Double?
    ) -> PlanGoalDirection? {
        guard let currentKg, let goalKg else {
            return goalType.planGoalDirection
        }
        let delta = goalKg - currentKg
        if delta < -FormaCalculationConstants.goalDirectionEpsilonKg {
            return .cut
        }
        if delta > FormaCalculationConstants.goalDirectionEpsilonKg {
            return .gain
        }
        return .maintain
    }

    private static func weightToLoseOrGainKg(
        direction: PlanGoalDirection?,
        currentKg: Double?,
        goalKg: Double?
    ) -> Double? {
        guard let currentKg, let goalKg, let direction else { return nil }
        switch direction {
        case .cut:
            let delta = currentKg - goalKg
            return delta > 0.1 ? delta : nil
        case .gain:
            let delta = goalKg - currentKg
            return delta > 0.1 ? delta : nil
        case .maintain:
            return nil
        }
    }

    private static func weightChangeLabel(
        direction: PlanGoalDirection?,
        deltaKg: Double?
    ) -> String? {
        switch direction {
        case .maintain:
            return FormaProductCopy.PlanEditHero.maintainingTarget
        case .cut, .gain:
            guard let deltaKg, deltaKg > 0.1 else {
                return FormaProductCopy.PlanEditHero.maintainingTarget
            }
            return FormaProductCopy.PlanEditHero.totalChangeToTarget(formatKg(deltaKg))
        case .none:
            return nil
        }
    }

    private struct TimelineMetrics {
        let weeklyRateKg: Double?
        let monthlyRateKg: Double?
        let estimatedWeeks: Int?
        let estimatedCompletionDate: Date?
        let estimatedCompletionLabel: String?
    }

    private static func timelineMetrics(
        direction: PlanGoalDirection?,
        currentKg: Double?,
        goalKg: Double?,
        weeklyRateKg: Double?,
        goalDatePace: Date?,
        referenceDate: Date,
        calendar: Calendar
    ) -> TimelineMetrics {
        if let goalDatePace, goalDatePace > referenceDate {
            let completionLabel = FormaProductCopy.PlanEditHero.estimatedFinish(
                formattedMonthYear(goalDatePace, calendar: calendar)
            )
            return TimelineMetrics(
                weeklyRateKg: weeklyRateKg,
                monthlyRateKg: monthlyRateFromWeekly(weeklyRateKg),
                estimatedWeeks: nil,
                estimatedCompletionDate: goalDatePace,
                estimatedCompletionLabel: completionLabel
            )
        }

        guard direction == .cut,
              let currentKg,
              let goalKg,
              let weeklyRateKg,
              weeklyRateKg > 0
        else {
            return TimelineMetrics(
                weeklyRateKg: direction == .cut ? weeklyRateKg : nil,
                monthlyRateKg: monthlyRateFromWeekly(weeklyRateKg),
                estimatedWeeks: nil,
                estimatedCompletionDate: nil,
                estimatedCompletionLabel: nil
            )
        }

        guard let weeks = OnboardingGoalProjectionBuilder.estimatedWeeks(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg,
            weeklyLossKg: weeklyRateKg
        ), weeks > 0, weeks <= maxEstimatedWeeks else {
            return TimelineMetrics(
                weeklyRateKg: weeklyRateKg,
                monthlyRateKg: monthlyRateFromWeekly(weeklyRateKg),
                estimatedWeeks: nil,
                estimatedCompletionDate: nil,
                estimatedCompletionLabel: nil
            )
        }

        let completionDate = calendar.date(byAdding: .day, value: weeks * 7, to: referenceDate)
        let completionLabel = completionDate.map {
            FormaProductCopy.PlanEditHero.estimatedFinish(formattedMonthYear($0, calendar: calendar))
        }

        return TimelineMetrics(
            weeklyRateKg: weeklyRateKg,
            monthlyRateKg: monthlyRateFromWeekly(weeklyRateKg),
            estimatedWeeks: weeks,
            estimatedCompletionDate: completionDate,
            estimatedCompletionLabel: completionLabel
        )
    }

    private static func resolvedWeeklyRateKg(
        engineResult: PlanCalculationResult?,
        pacePreview: WeightLossPacePreviewModel,
        caloriePreview: CalorieTargetResult?
    ) -> Double? {
        if let engineResult, engineResult.goalDirection == .cut, engineResult.weightLossRateKgPerWeek > 0 {
            return engineResult.weightLossRateKgPerWeek
        }
        if let weekly = caloriePreview?.targets.expectedWeeklyWeightLossKg, weekly > 0 {
            return weekly
        }
        return pacePreview.weeklyLossKg
    }

    private static func monthlyRateFromWeekly(_ weeklyRateKg: Double?) -> Double? {
        guard let weeklyRateKg, weeklyRateKg > 0 else { return nil }
        let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
        return weeklyRateKg * weeksPerMonth
    }

    // MARK: - Energy

    private struct EnergyMetrics {
        let maintenanceCalories: Int?
        let dailyBalanceKcal: Int?
        let dailyBalanceLabel: String?
    }

    private static func energyMetrics(
        direction: PlanGoalDirection?,
        engineResult: PlanCalculationResult?,
        caloriePreview: CalorieTargetResult?,
        pacePreview: WeightLossPacePreviewModel
    ) -> EnergyMetrics {
        if let engineResult {
            return energyMetrics(from: engineResult)
        }
        if let caloriePreview {
            return energyMetrics(from: caloriePreview, direction: direction)
        }
        if let deficit = pacePreview.dailyDeficitKcal, direction == .cut {
            return EnergyMetrics(
                maintenanceCalories: nil,
                dailyBalanceKcal: -deficit,
                dailyBalanceLabel: FormaProductCopy.PlanProjection.dailyDeficit(deficit)
            )
        }
        return EnergyMetrics(maintenanceCalories: nil, dailyBalanceKcal: nil, dailyBalanceLabel: nil)
    }

    private static func energyMetrics(from result: PlanCalculationResult) -> EnergyMetrics {
        switch result.goalDirection {
        case .cut:
            let deficit = result.dailyDeficitKcal
            return EnergyMetrics(
                maintenanceCalories: result.tdeeKcal,
                dailyBalanceKcal: deficit > 0 ? -deficit : 0,
                dailyBalanceLabel: deficit > 0
                    ? FormaProductCopy.PlanProjection.dailyDeficit(deficit)
                    : FormaProductCopy.PlanProjection.dailyBalanceNeutral
            )
        case .gain:
            let surplus = max(result.calorieTargetKcal - result.tdeeKcal, 0)
            return EnergyMetrics(
                maintenanceCalories: result.tdeeKcal,
                dailyBalanceKcal: surplus,
                dailyBalanceLabel: surplus > 0
                    ? FormaProductCopy.PlanProjection.dailySurplus(surplus)
                    : FormaProductCopy.PlanProjection.dailyBalanceNeutral
            )
        case .maintain:
            return EnergyMetrics(
                maintenanceCalories: result.tdeeKcal,
                dailyBalanceKcal: 0,
                dailyBalanceLabel: FormaProductCopy.PlanProjection.dailyBalanceNeutral
            )
        }
    }

    private static func energyMetrics(
        from preview: CalorieTargetResult,
        direction: PlanGoalDirection?
    ) -> EnergyMetrics {
        let deficit = preview.estimatedDailyDeficit
        switch direction {
        case .cut:
            return EnergyMetrics(
                maintenanceCalories: preview.estimatedTDEE,
                dailyBalanceKcal: deficit > 0 ? -deficit : 0,
                dailyBalanceLabel: deficit > 0
                    ? FormaProductCopy.PlanProjection.dailyDeficit(deficit)
                    : FormaProductCopy.PlanProjection.dailyBalanceNeutral
            )
        case .gain:
            let surplus = max(preview.targets.calorieTarget - preview.estimatedTDEE, 0)
            return EnergyMetrics(
                maintenanceCalories: preview.estimatedTDEE,
                dailyBalanceKcal: surplus,
                dailyBalanceLabel: surplus > 0
                    ? FormaProductCopy.PlanProjection.dailySurplus(surplus)
                    : FormaProductCopy.PlanProjection.dailyBalanceNeutral
            )
        case .maintain, .none:
            return EnergyMetrics(
                maintenanceCalories: preview.estimatedTDEE,
                dailyBalanceKcal: 0,
                dailyBalanceLabel: FormaProductCopy.PlanProjection.dailyBalanceNeutral
            )
        }
    }

    // MARK: - Targets

    private struct TargetMetrics {
        let calories: Int?
        let proteinG: Double?
        let carbG: Double?
        let fatG: Double?
        let waterMl: Int?
    }

    private static func targetMetrics(
        engineResult: PlanCalculationResult?,
        caloriePreview: CalorieTargetResult?,
        formState: PlanFormState
    ) -> TargetMetrics {
        if let engineResult {
            return TargetMetrics(
                calories: engineResult.calorieTargetKcal,
                proteinG: engineResult.proteinTargetG,
                carbG: engineResult.carbTargetG,
                fatG: engineResult.fatTargetG,
                waterMl: engineResult.waterTargetMl
            )
        }
        if let caloriePreview {
            let targets = caloriePreview.targets
            return TargetMetrics(
                calories: targets.calorieTarget,
                proteinG: targets.proteinTarget,
                carbG: targets.carbTarget,
                fatG: targets.fatTarget,
                waterMl: targets.waterTargetMl
            )
        }
        return TargetMetrics(
            calories: parsedPositiveInt(formState.calorieTargetText),
            proteinG: parsedPositiveDouble(formState.proteinTargetText),
            carbG: parsedPositiveDouble(formState.carbTargetText),
            fatG: parsedPositiveDouble(formState.fatTargetText),
            waterMl: parsedPositiveInt(formState.waterTargetMlText)
        )
    }

    // MARK: - Difficulty

    private struct DifficultyMetrics {
        let label: String
        let description: String
        let adherence: String
        let recovery: String
        let hunger: String
    }

    private static func difficultyMetrics(
        goalType: PlanGoalType,
        direction: PlanGoalDirection?,
        paceChoice: WeightLossPaceChoice,
        engineResult: PlanCalculationResult?,
        pacePreview: WeightLossPacePreviewModel
    ) -> DifficultyMetrics {
        let resolvedDirection = direction ?? goalType.planGoalDirection
        let label = OnboardingPlanRevealStrategyFormatter.label(
            goalDirection: resolvedDirection,
            paceChoice: paceChoice
        )
        let description = sustainabilityNote(for: engineResult)
            ?? difficultyDescriptionFallback(
                direction: resolvedDirection,
                paceChoice: paceChoice
            )
        let tier = difficultyTier(
            engineResult: engineResult,
            pacePreview: pacePreview,
            paceChoice: paceChoice,
            direction: resolvedDirection
        )
        let impacts = impactCopy(tier: tier, direction: resolvedDirection, paceChoice: paceChoice)

        return DifficultyMetrics(
            label: label,
            description: description,
            adherence: impacts.adherence,
            recovery: impacts.recovery,
            hunger: impacts.hunger
        )
    }

    private enum DifficultyTier {
        case gentle
        case moderate
        case demanding
        case aggressive
    }

    private static func difficultyTier(
        engineResult: PlanCalculationResult?,
        pacePreview: WeightLossPacePreviewModel,
        paceChoice: WeightLossPaceChoice,
        direction: PlanGoalDirection
    ) -> DifficultyTier {
        if let engineResult {
            switch engineResult.safetyLevel {
            case .ok:
                break
            case .caution:
                return paceChoice == .gentle ? .moderate : .demanding
            case .strongWarning, .error:
                return .aggressive
            }
        }

        if pacePreview.safetyDisplay == .tooAggressive {
            return .aggressive
        }
        if pacePreview.safetyDisplay == .demanding || pacePreview.warningMessage != nil {
            return .demanding
        }

        switch direction {
        case .maintain:
            return .gentle
        case .gain:
            return paceChoice == .aggressive ? .demanding : .moderate
        case .cut:
            switch paceChoice {
            case .gentle:
                return .gentle
            case .moderate, .advanced:
                return .moderate
            case .aggressive:
                return .aggressive
            }
        }
    }

    private static func sustainabilityNote(for result: PlanCalculationResult?) -> String? {
        guard let result else { return nil }
        switch result.safetyLevel {
        case .ok:
            return "This pace is designed to be sustainable alongside your training and recovery."
        case .caution:
            if result.warnings.contains(where: { $0.code == "paceAggressive" }) {
                return "This pace is demanding — monitor energy and recovery, and adjust if needed."
            }
            if result.calories.calorieFloorApplied {
                return "A minimum calorie floor is applied to keep intake supportive of recovery."
            }
            return "This plan balances progress with recovery — listen to your body as you train."
        case .strongWarning:
            return WeightLossPacePreviewBuilder.paceWarningCopy
        case .error:
            return nil
        }
    }

    private static func difficultyDescriptionFallback(
        direction: PlanGoalDirection,
        paceChoice: WeightLossPaceChoice
    ) -> String {
        let copy = FormaProductCopy.PlanRationale.self
        switch direction {
        case .cut:
            switch paceChoice {
            case .gentle:
                return copy.guidanceGentleCut
            case .moderate, .advanced:
                return copy.guidanceModerateCut
            case .aggressive:
                return copy.guidanceAggressiveCut
            }
        case .maintain:
            return copy.guidanceMaintenance
        case .gain:
            return copy.guidanceLeanGain
        }
    }

    private static func impactCopy(
        tier: DifficultyTier,
        direction: PlanGoalDirection,
        paceChoice: WeightLossPaceChoice
    ) -> (adherence: String, recovery: String, hunger: String) {
        let copy = FormaProductCopy.PlanProjection.self
        let status = FormaProductCopy.PlanStatus.self

        switch (direction, tier) {
        case (.maintain, _):
            return (copy.adherenceHigh, copy.recoveryLow, copy.hungerLow)
        case (.gain, .gentle), (.gain, .moderate):
            return (copy.adherenceModerate, copy.recoveryModerate, copy.hungerModerate)
        case (.gain, .demanding), (.gain, .aggressive):
            return (copy.adherenceChallenging, copy.recoveryHigh, status.leanGainWatchFor)
        case (.cut, .gentle):
            return (copy.adherenceHigh, copy.recoveryLow, copy.hungerLow)
        case (.cut, .moderate):
            return (copy.adherenceModerate, copy.recoveryModerate, status.moderateCutWatchFor)
        case (.cut, .demanding):
            return (copy.adherenceModerate, copy.recoveryModerate, status.moderateCutWatchFor)
        case (.cut, .aggressive):
            return (copy.adherenceChallenging, copy.recoveryHigh, status.aggressiveCutWatchFor)
        }
    }

    // MARK: - Labels

    private static func goalLabel(for goalType: PlanGoalType) -> String {
        goalType.rawValue
    }

    // MARK: - Parsing & formatting

    private static func parsedPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private static func parsedPositiveInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return value
    }

    private static func parsedPositiveDouble(_ text: String) -> Double? {
        parsedPositive(text)
    }

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

private extension PlanGoalType {
    var planGoalDirection: PlanGoalDirection {
        switch self {
        case .loseFat:
            return .cut
        case .maintain:
            return .maintain
        case .gainMuscle:
            return .gain
        }
    }
}
