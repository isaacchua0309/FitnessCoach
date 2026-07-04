//
//  PlanWeeklyRecommendationStateBuilder.swift
//  Fitness Coach
//
//  Forma — Learned maintenance and safe weekly plan recommendation for Plan.
//

import Foundation

enum PlanWeeklyRecommendationStateBuilder {

    static func build(
        context: PlanDashboardContext,
        planResult: PlanCalculationResult?,
        referenceDate: Date,
        weeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding = WeeklyProgressSummaryBuilder(
            calendar: context.calendar
        )
    ) -> PlanWeeklyRecommendationState {
        let profile = context.profile
        let logs = context.maturityLogs.isEmpty ? context.weekLogs : context.maturityLogs
        let trainingDays = context.healthWorkoutDayStarts.isEmpty
            ? nil
            : context.healthWorkoutDayStarts

        let summary = weeklyProgressSummaryBuilder.buildSummary(
            asOf: referenceDate,
            profile: profile,
            dailyLogs: logs,
            weightEntries: context.allWeights,
            trainingDayStarts: trainingDays
        )

        let maintenance = summary.maintenanceEstimate
        let showsLearnedEstimate = maintenance.sufficiency.isEligibleForKcalMaintenanceDisplay
            && maintenance.estimatedMaintenanceKcal != nil

        let recommendation = planRecommendation(
            summary: summary,
            profile: profile,
            referenceDate: referenceDate
        )

        let formulaMaintenanceKcal = resolvedFormulaMaintenanceKcal(
            planResult: planResult,
            summary: summary
        )

        let showsRecommendation = recommendation.map { $0.kind != .notEnoughData } ?? false
        let suggestedTargetKcal = suggestedTargetKcal(
            recommendation: recommendation,
            profile: profile
        )

        var state = PlanWeeklyRecommendationState(
            sectionTitle: FormaProductCopy.PlanMissionControl.weeklyRecommendationSectionTitle,
            formulaMaintenanceLabel: FormaProductCopy.PlanMissionControl.formulaMaintenanceLabel,
            formulaMaintenanceKcal: formulaMaintenanceKcal,
            learnedMaintenanceLabel: FormaProductCopy.PlanMissionControl.learnedMaintenanceLabel,
            learnedMaintenanceKcal: showsLearnedEstimate ? maintenance.estimatedMaintenanceKcal : nil,
            learnedMaintenanceUnavailableCopy:
                FormaProductCopy.PlanMissionControl.learnedMaintenanceUnavailable,
            showsLearnedEstimate: showsLearnedEstimate,
            recommendationTitle: showsRecommendation ? recommendation?.title : nil,
            recommendationMessage: showsRecommendation ? recommendation?.message : nil,
            suggestedCalorieDelta: showsRecommendation ? recommendation?.suggestedCalorieDelta : nil,
            suggestedTargetKcal: showsRecommendation ? suggestedTargetKcal : nil,
            confidenceLabel: showsRecommendation
                ? shortConfidenceLabel(for: recommendation?.confidence ?? summary.confidence)
                : nil,
            showsRecommendation: showsRecommendation,
            reviewPlanButtonTitle: FormaProductCopy.PlanMissionControl.weeklyRecommendationReviewPlan,
            showsReviewPlanCTA: recommendation?.shouldShowPlanCTA == true,
            safetyCopy: FormaProductCopy.PlanMissionControl.weeklyRecommendationSafetyCopy,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state, summary: summary)
        return state
    }

    // MARK: Recommendation

    private static func planRecommendation(
        summary: WeeklyProgressSummary,
        profile: UserProfile,
        referenceDate: Date
    ) -> WeeklyPlanRecommendation? {
        guard WeeklyProgressConfidencePolicy.canShowPlanRecommendation(
            summary.maintenanceEstimate.sufficiency
        ) else {
            return nil
        }

        let goalDirection = JourneyGoalDirection.resolve(
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg
        )

        let planInput = PlanRecommendationInput(
            summary: summary,
            currentCalorieTargetKcal: calorieTargetKcal(from: profile),
            staticTDEEKcal: staticTDEEKcal(from: profile, referenceDate: referenceDate),
            calorieFloorKcal: calorieFloorKcal(from: profile, referenceDate: referenceDate),
            goalDirection: goalDirection
        )

        return PlanRecommendationPolicy.recommend(planInput)
    }

    // MARK: Helpers

    private static func resolvedFormulaMaintenanceKcal(
        planResult: PlanCalculationResult?,
        summary: WeeklyProgressSummary
    ) -> Int? {
        if let tdee = planResult?.tdeeKcal, tdee > 0 {
            return tdee
        }
        return summary.maintenanceEstimate.staticTDEEKcal
    }

    private static func suggestedTargetKcal(
        recommendation: WeeklyPlanRecommendation?,
        profile: UserProfile
    ) -> Int? {
        guard let recommendation,
              let delta = recommendation.suggestedCalorieDelta,
              let currentTarget = calorieTargetKcal(from: profile) else {
            return nil
        }
        return currentTarget + delta
    }

    private static func calorieTargetKcal(from profile: UserProfile) -> Int? {
        guard profile.targets.calorieTarget > 0 else { return nil }
        return profile.targets.calorieTarget
    }

    private static func staticTDEEKcal(
        from profile: UserProfile,
        referenceDate: Date
    ) -> Int? {
        guard let result = try? PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        ) else {
            return nil
        }
        return result.tdeeKcal
    }

    private static func calorieFloorKcal(
        from profile: UserProfile,
        referenceDate: Date
    ) -> Int? {
        guard let result = try? PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        ) else {
            return nil
        }
        return result.calories.calorieFloorKcal
    }

    private static func shortConfidenceLabel(
        for confidence: WeeklyProgressConfidenceLevel
    ) -> String {
        switch confidence {
        case .unavailable:
            return FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
        case .low:
            return FormaProductCopy.WeeklyReviewPresentation.confidenceLow
        case .medium:
            return FormaProductCopy.WeeklyReviewPresentation.confidenceModerate
        case .high:
            return FormaProductCopy.WeeklyReviewPresentation.confidenceHigh
        }
    }

    private static func accessibilitySummary(
        for state: PlanWeeklyRecommendationState,
        summary: WeeklyProgressSummary
    ) -> String {
        var parts = [state.sectionTitle]

        if let formula = state.formulaMaintenanceKcal {
            parts.append(
                "\(state.formulaMaintenanceLabel). About \(formula) kilocalories per day."
            )
        } else {
            parts.append("\(state.formulaMaintenanceLabel). Unavailable.")
        }

        if state.showsLearnedEstimate, let learned = state.learnedMaintenanceKcal {
            parts.append(
                "\(state.learnedMaintenanceLabel). About \(learned) kilocalories per day."
            )
        } else {
            parts.append(state.learnedMaintenanceUnavailableCopy)
        }

        if state.showsRecommendation,
           let title = state.recommendationTitle,
           let message = state.recommendationMessage {
            parts.append("\(title). \(message)")
            if let confidence = state.confidenceLabel {
                parts.append(confidence)
            }
        }

        if state.showsReviewPlanCTA {
            parts.append(state.reviewPlanButtonTitle)
        }

        parts.append(state.safetyCopy)

        if summary.hasSuddenSpike {
            parts.append(FormaProductCopy.WeightSpikeEducation.accessibilityLabel)
        }

        return parts.joined(separator: ". ")
    }
}
