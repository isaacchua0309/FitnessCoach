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
            weeklyChangeLabel: timeline.weeklyChangeLabel,
            estimatedWeeksLabel: timeline.estimatedWeeksLabel,
            journeySummaryLine: journeySummaryLine(
                direction: direction,
                goalWeightKg: goalWeightKg
            ),
            dailyCalorieLabel: OnboardingFormatter.kcal(plan.targets.calorieTarget),
            calorieExplanationLine: calorieExplanationLine(
                direction: direction,
                plan: plan
            ),
            macroRows: macroRows(from: plan),
            warningMessage: warningMessage(plan: plan, pacePreview: pacePreview),
            firstWeekFocusItems: FormaProductCopy.Onboarding.V2.PlanReveal.firstWeekBullets
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
            return CutTimeline(weeklyChangeLabel: nil, estimatedWeeksLabel: nil)
        }

        let weeklyKg = plan.targets.expectedWeeklyWeightLossKg ?? pacePreview.weeklyLossKg
        guard let weeklyKg, weeklyKg > 0 else {
            return CutTimeline(weeklyChangeLabel: nil, estimatedWeeksLabel: nil)
        }

        let remainingKg = currentWeightKg - goalWeightKg
        guard remainingKg > 0 else {
            return CutTimeline(weeklyChangeLabel: nil, estimatedWeeksLabel: nil)
        }

        let weeklyChangeLabel = expectedPaceLabel(weeklyKg: weeklyKg)
        let estimatedWeeks = Int(ceil(remainingKg / weeklyKg))
        let estimatedWeeksLabel = estimatedTimelineLabel(weeks: estimatedWeeks)

        return CutTimeline(
            weeklyChangeLabel: weeklyChangeLabel,
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

    private static func calorieExplanationLine(
        direction: PlanGoalDirection,
        plan: CalorieTargetResult
    ) -> String {
        switch direction {
        case .cut:
            let deficit = plan.estimatedDailyDeficit
            guard deficit > 0 else {
                return "A moderate deficit designed to protect energy and training."
            }
            if plan.isAggressive {
                return "About \(deficit) kcal/day below maintenance — demanding, so watch energy and recovery."
            }
            return "About \(deficit) kcal/day below your estimated maintenance."
        case .maintain:
            return FormaProductCopy.Onboarding.V2.PlanReveal.maintainCalorieExplanation
        case .gain:
            return FormaProductCopy.Onboarding.V2.PlanReveal.gainCalorieExplanation
        }
    }

    private static func expectedPaceLabel(weeklyKg: Double) -> String {
        let pace = OnboardingFormatter.weeklyLoss(weeklyKg) ?? formattedWeeklyLoss(weeklyKg)
        return "Expected pace: \(pace)"
    }

    private static func estimatedTimelineLabel(weeks: Int) -> String {
        "Estimated timeline: About \(weeks) weeks"
    }

    private static func macroRows(from plan: CalorieTargetResult) -> [OnboardingPlanRevealMetricRow] {
        [
            OnboardingPlanRevealMetricRow(
                label: "Protein",
                value: OnboardingFormatter.grams(plan.targets.proteinTarget)
            ),
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

    private static func warningMessage(
        plan: CalorieTargetResult,
        pacePreview: WeightLossPacePreviewModel
    ) -> String? {
        if let planWarning = plan.warning?.trimmingCharacters(in: .whitespacesAndNewlines),
           !planWarning.isEmpty {
            return planWarning
        }
        if let paceWarning = pacePreview.warningMessage {
            return paceWarning
        }
        if plan.isAggressive {
            return FormaProductCopy.Onboarding.aggressivePlanWarning
        }
        return nil
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
