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

        let unitSystem = formState.unitSystem
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

        let currentLabel = weightLabel(currentWeightKg, unitSystem: unitSystem)
        let goalLabel = weightLabel(goalWeightKg, unitSystem: unitSystem)
        let heroCopy = goalHeroCopy(
            direction: direction,
            goalLabel: goalLabel
        )
        let strategyLabel = OnboardingPlanRevealStrategyFormatter.label(
            goalDirection: direction,
            paceChoice: formState.weightLossPaceChoice
        )
        let planStatus = OnboardingPlanRevealStatusFormatter.resolve(
            plan: plan,
            pacePreview: pacePreview,
            goalDirection: direction
        )

        let missions = firstWeekMissions(for: direction)
        let coach = coachMessage(direction: direction, goalLabel: goalLabel)
        let beliefLine = journeyBeliefLine(
            direction: direction,
            strategyLabel: strategyLabel,
            paceChoice: formState.weightLossPaceChoice,
            weeklyLossKg: plan.targets.expectedWeeklyWeightLossKg ?? pacePreview.weeklyLossKg,
            calorieTarget: plan.targets.calorieTarget
        )
        let calorieExplanation = OnboardingPlanRevealStrategyFormatter.calorieExplanation(
            goalDirection: direction
        )
        let calorieLabel = OnboardingFormatter.kcal(plan.targets.calorieTarget)
        let proteinLabel = OnboardingFormatter.grams(plan.targets.proteinTarget)
        let waterLabel = OnboardingFormatter.ml(plan.targets.waterTargetMl)

        return OnboardingPlanRevealState(
            goalDirection: direction,
            currentWeightLabel: currentLabel,
            goalWeightLabel: goalLabel,
            goalProgressLabel: goalProgressLabel(current: currentLabel, goal: goalLabel),
            goalHeroSectionTitle: heroCopy.sectionTitle,
            goalHeroHeadline: heroCopy.headline,
            accessibilitySummary: accessibilitySummary(
                celebrationTitle: FormaProductCopy.Onboarding.Flow.PlanReveal.title,
                celebrationSubtitle: FormaProductCopy.Onboarding.Flow.PlanReveal.subtitle,
                goalHeroHeadline: heroCopy.headline,
                goalProgressLabel: goalProgressLabel(current: currentLabel, goal: goalLabel),
                journeyBeliefLine: beliefLine,
                paceLabel: timeline.paceLabel,
                estimatedWeeksLabel: timeline.estimatedWeeksLabel,
                strategyLabel: strategyLabel,
                calorieTarget: plan.targets.calorieTarget,
                proteinLabel: proteinLabel,
                waterLabel: waterLabel,
                calorieExplanationLine: calorieExplanation,
                firstWeekMissions: missions,
                coachMessage: coach
            ),
            paceLabel: timeline.paceLabel,
            estimatedWeeksLabel: timeline.estimatedWeeksLabel,
            strategyLabel: strategyLabel,
            dailyCalorieLabel: calorieLabel,
            calorieExplanationLine: calorieExplanation,
            proteinLabel: proteinLabel,
            waterLabel: waterLabel,
            secondaryMacroRows: secondaryMacroRows(from: plan),
            journeyBeliefLine: beliefLine,
            firstWeekMissions: missions,
            coachMessage: coach,
            planStatus: planStatus
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
            return CutTimeline(paceLabel: nil, estimatedWeeksLabel: nil)
        }

        let weeklyKg = plan.targets.expectedWeeklyWeightLossKg ?? pacePreview.weeklyLossKg
        guard let weeklyKg, weeklyKg > 0 else {
            return CutTimeline(paceLabel: nil, estimatedWeeksLabel: nil)
        }

        let remainingKg = currentWeightKg - goalWeightKg
        guard remainingKg > 0 else {
            return CutTimeline(paceLabel: nil, estimatedWeeksLabel: nil)
        }

        let paceLabel = compactPaceLabel(weeklyKg: weeklyKg)
        let estimatedWeeks = Int(ceil(remainingKg / weeklyKg))
        let estimatedWeeksLabel = estimatedTimelineLabel(weeks: estimatedWeeks)

        return CutTimeline(
            paceLabel: paceLabel,
            estimatedWeeksLabel: estimatedWeeksLabel
        )
    }

    // MARK: - Copy

    private struct GoalHeroCopy {
        let sectionTitle: String
        let headline: String
    }

    private static func goalHeroCopy(
        direction: PlanGoalDirection,
        goalLabel: String
    ) -> GoalHeroCopy {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.GoalHero.self
        switch direction {
        case .maintain:
            return GoalHeroCopy(
                sectionTitle: copy.sectionTitle,
                headline: copy.maintainHeadline(targetWeight: goalLabel)
            )
        case .cut:
            return GoalHeroCopy(
                sectionTitle: copy.sectionTitle,
                headline: copy.lossHeadline(targetWeight: goalLabel)
            )
        case .gain:
            return GoalHeroCopy(
                sectionTitle: copy.sectionTitle,
                headline: copy.gainHeadline(targetWeight: goalLabel)
            )
        }
    }

    private static func goalProgressLabel(current: String, goal: String) -> String {
        "\(current) → \(goal)"
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

    private static func journeyBeliefLine(
        direction: PlanGoalDirection,
        strategyLabel: String,
        paceChoice: WeightLossPaceChoice,
        weeklyLossKg: Double?,
        calorieTarget: Int
    ) -> String {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.JourneyBelief.self
        switch direction {
        case .cut:
            return cutJourneyBeliefLine(
                paceChoice: paceChoice,
                weeklyLossKg: weeklyLossKg,
                calorieTarget: calorieTarget,
                fallback: copy.cut(strategyLabel: strategyLabel)
            )
        case .maintain:
            return copy.maintain
        case .gain:
            return copy.gain
        }
    }

    private static func cutJourneyBeliefLine(
        paceChoice: WeightLossPaceChoice,
        weeklyLossKg: Double?,
        calorieTarget: Int,
        fallback: String
    ) -> String {
        guard let weeklyLoss = OnboardingFormatter.weeklyLoss(weeklyLossKg) else {
            return fallback
        }

        let paceName = paceChoice.isAdvanced
            ? "custom"
            : paceChoice.displayName.lowercased()
        return "Your plan is built for a \(paceName) pace of about \(weeklyLoss), with \(calorieTarget) kcal/day as your starting target."
    }

    private static func firstWeekMissions(
        for direction: PlanGoalDirection
    ) -> [OnboardingPlanRevealMission] {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.FirstWeek.self
        switch direction {
        case .cut:
            return [
                OnboardingPlanRevealMission(icon: "fork.knife", title: copy.logMealsCut),
                OnboardingPlanRevealMission(icon: "figure.strengthtraining.traditional", title: copy.proteinCut),
                OnboardingPlanRevealMission(icon: "scalemass", title: copy.weighCut)
            ]
        case .maintain:
            return [
                OnboardingPlanRevealMission(icon: "calendar", title: copy.logDaysMaintain),
                OnboardingPlanRevealMission(icon: "flame", title: copy.caloriesMaintain),
                OnboardingPlanRevealMission(icon: "drop.fill", title: copy.waterMaintain)
            ]
        case .gain:
            return [
                OnboardingPlanRevealMission(icon: "fork.knife", title: copy.mealsGain),
                OnboardingPlanRevealMission(icon: "figure.strengthtraining.traditional", title: copy.proteinGain),
                OnboardingPlanRevealMission(icon: "scalemass", title: copy.weighGain)
            ]
        }
    }

    private static func coachMessage(
        direction: PlanGoalDirection,
        goalLabel: String
    ) -> String {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.Coach.self
        switch direction {
        case .cut:
            return copy.cut(goalWeight: goalLabel)
        case .maintain:
            return copy.maintain
        case .gain:
            return copy.gain(goalWeight: goalLabel)
        }
    }

    private static func accessibilitySummary(
        celebrationTitle: String,
        celebrationSubtitle: String,
        goalHeroHeadline: String,
        goalProgressLabel: String,
        journeyBeliefLine: String,
        paceLabel: String?,
        estimatedWeeksLabel: String?,
        strategyLabel: String,
        calorieTarget: Int,
        proteinLabel: String,
        waterLabel: String,
        calorieExplanationLine: String,
        firstWeekMissions: [OnboardingPlanRevealMission],
        coachMessage: String
    ) -> String {
        let labels = FormaProductCopy.Onboarding.V2.PlanReveal.Accessibility.self

        let celebration = "\(celebrationTitle). \(celebrationSubtitle)"
        let goal = "\(labels.goal): \(goalHeroHeadline)."

        var journeyParts = [goalProgressLabel, strategyLabel, journeyBeliefLine]
        if let paceLabel {
            journeyParts.insert(paceLabel, at: 1)
        }
        if let estimatedWeeksLabel {
            let insertIndex = paceLabel == nil ? 1 : 2
            journeyParts.insert(estimatedWeeksLabel, at: insertIndex)
        }
        let journey = "\(labels.journey): \(journeyParts.joined(separator: ". "))."

        let firstWeek = "\(labels.firstWeek): \(firstWeekMissions.map(\.title).joined(separator: ", "))."

        let proteinSpoken = proteinLabel.replacingOccurrences(of: " g", with: " grams")
        let waterSpoken = waterLabel.replacingOccurrences(of: " ml", with: " milliliters")
        let dailyFuel =
            "\(labels.dailyFuel): \(calorieExplanationLine) \(calorieTarget) calories, \(proteinSpoken) protein, \(waterSpoken) water."

        return [
            celebration,
            goal,
            journey,
            firstWeek,
            dailyFuel,
            coachMessage
        ].joined(separator: " ")
    }

    // MARK: - Formatting

    private static func weightLabel(_ kg: Double, unitSystem: UnitSystem) -> String {
        OnboardingGoalWeightBounds.weightSummary(valueKg: kg, unitSystem: unitSystem)
    }

    private static func formattedWeeklyLoss(_ weeklyKg: Double) -> String {
        weeklyKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weeklyKg)) kg/week"
            : String(format: "%.1f kg/week", weeklyKg)
    }
}
