//
//  OnboardingPlanRevealBuilder.swift
//  Fitness Coach
//
//  Forma — Builds journey-first onboarding plan reveal copy from deterministic inputs.
//

import Foundation

enum OnboardingPlanRevealBuilder {

    static func build(
        formState: OnboardingFormState,
        plan: CalorieTargetResult,
        referenceDate: Date = Date()
    ) -> OnboardingPlanRevealState? {
        guard let currentWeightKg = formState.parsedCurrentWeightKg,
              let goalWeightKg = formState.parsedGoalWeightKg else {
            return nil
        }

        let direction = goalDirection(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg
        )
        let pacePreview = formState.pacePreview(referenceDate: referenceDate)
        let timeline = cutTimeline(
            direction: direction,
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            plan: plan,
            pacePreview: pacePreview
        )

        return OnboardingPlanRevealState(
            currentWeightLabel: weightLabel(currentWeightKg),
            goalWeightLabel: weightLabel(goalWeightKg),
            goalProgressLabel: goalProgressLabel(
                current: weightLabel(currentWeightKg),
                goal: weightLabel(goalWeightKg)
            ),
            weeklyChangeLabel: timeline.weeklyChangeLabel,
            paceLabel: timeline.paceLabel,
            estimatedWeeksLabel: timeline.estimatedWeeksLabel,
            journeySummaryLine: journeySummaryLine(
                direction: direction,
                goalWeightKg: goalWeightKg
            ),
            strategyLabel: OnboardingPlanRevealStrategyFormatter.label(
                goalDirection: direction,
                paceChoice: formState.weightLossPaceChoice
            ),
            dailyCalorieLabel: OnboardingFormatter.kcal(plan.targets.calorieTarget),
            calorieExplanationLine: OnboardingPlanRevealStrategyFormatter.calorieExplanation(
                goalDirection: direction
            ),
            proteinLabel: OnboardingFormatter.grams(plan.targets.proteinTarget),
            waterLabel: OnboardingFormatter.ml(plan.targets.waterTargetMl),
            secondaryMacroRows: secondaryMacroRows(from: plan),
            planStatus: OnboardingPlanRevealStatusFormatter.resolve(
                plan: plan,
                pacePreview: pacePreview,
                goalDirection: direction
            )
        )
    }

    // MARK: - Goal direction

    private static func goalDirection(
        currentWeightKg: Double,
        goalWeightKg: Double
    ) -> PlanGoalDirection {
        let deltaKg = goalWeightKg - currentWeightKg
        if deltaKg < -FormaCalculationConstants.goalDirectionEpsilonKg {
            return .cut
        }
        if deltaKg > FormaCalculationConstants.goalDirectionEpsilonKg {
            return .gain
        }
        return .maintain
    }

    // MARK: - Cut timeline

    private struct CutTimeline {
        let weeklyChangeLabel: String?
        let paceLabel: String?
        let estimatedWeeksLabel: String?
    }

    private static func cutTimeline(
        direction: PlanGoalDirection,
        currentWeightKg: Double,
        goalWeightKg: Double,
        plan: CalorieTargetResult,
        pacePreview: WeightLossPacePreviewModel
    ) -> CutTimeline {
        guard direction == .cut else {
            return CutTimeline(weeklyChangeLabel: nil, paceLabel: nil, estimatedWeeksLabel: nil)
        }

        let weeklyKg = plan.targets.expectedWeeklyWeightLossKg ?? pacePreview.weeklyLossKg
        guard let weeklyKg, weeklyKg > 0 else {
            return CutTimeline(weeklyChangeLabel: nil, paceLabel: nil, estimatedWeeksLabel: nil)
        }

        let remainingKg = currentWeightKg - goalWeightKg
        guard remainingKg > 0 else {
            return CutTimeline(weeklyChangeLabel: nil, paceLabel: nil, estimatedWeeksLabel: nil)
        }

        let paceLabel = compactPaceLabel(weeklyKg: weeklyKg)
        let weeklyChangeLabel = expectedPaceLabel(weeklyKg: weeklyKg)
        let estimatedWeeks = Int(ceil(remainingKg / weeklyKg))
        let estimatedWeeksLabel = estimatedTimelineLabel(weeks: estimatedWeeks)

        return CutTimeline(
            weeklyChangeLabel: weeklyChangeLabel,
            paceLabel: paceLabel,
            estimatedWeeksLabel: estimatedWeeksLabel
        )
    }

    // MARK: - Copy

    private static func journeySummaryLine(
        direction: PlanGoalDirection,
        goalWeightKg: Double
    ) -> String {
        switch direction {
        case .cut:
            return Copy.startingTargetsAdjustWithData
        case .maintain:
            return Copy.maintainGoalSummary(goalWeightLabel: weightLabel(goalWeightKg))
        case .gain:
            return Copy.gainGoalSummary(goalWeightLabel: weightLabel(goalWeightKg))
        }
    }

    private static func goalProgressLabel(current: String, goal: String) -> String {
        "\(current) → \(goal)"
    }

    private static func expectedPaceLabel(weeklyKg: Double) -> String {
        let pace = OnboardingFormatter.weeklyLoss(weeklyKg) ?? formattedWeeklyLoss(weeklyKg)
        return "Expected pace: \(pace)"
    }

    private static func compactPaceLabel(weeklyKg: Double) -> String {
        OnboardingFormatter.weeklyLoss(weeklyKg) ?? formattedWeeklyLoss(weeklyKg)
    }

    private static func estimatedTimelineLabel(weeks: Int) -> String {
        OnboardingGoalProjectionBuilder.estimatedTimelineLabel(weeks: weeks)
    }

    private static func secondaryMacroRows(from plan: CalorieTargetResult) -> [OnboardingPlanRevealMetricRow] {
        [
            OnboardingPlanRevealMetricRow(
                label: "Carbs",
                value: OnboardingFormatter.grams(plan.targets.carbTarget)
            ),
            OnboardingPlanRevealMetricRow(
                label: "Fat",
                value: OnboardingFormatter.grams(plan.targets.fatTarget)
            )
        ]
    }

    // MARK: - Formatting

    private static func weightLabel(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kg)) kg"
            : String(format: "%.1f kg", kg)
    }

    private static func formattedWeeklyLoss(_ weeklyKg: Double) -> String {
        weeklyKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weeklyKg)) kg/week"
            : String(format: "%.1f kg/week", weeklyKg)
    }

    private enum Copy {
        static let startingTargetsAdjustWithData =
            "These are your starting targets. Forma will adjust as real data comes in."

        static func maintainGoalSummary(goalWeightLabel: String) -> String {
            "These are your starting targets for maintaining around \(goalWeightLabel). Forma will adjust as real data comes in."
        }

        static func gainGoalSummary(goalWeightLabel: String) -> String {
            "These are your starting targets for building toward \(goalWeightLabel). Forma will adjust as real data comes in."
        }
    }
}
