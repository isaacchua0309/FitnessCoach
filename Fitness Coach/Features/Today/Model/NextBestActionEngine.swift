//
//  NextBestActionEngine.swift
//  Fitness Coach
//
//  Deterministic single next-best-action selection for Today (no AI).
//

import Foundation

struct NextBestActionInput: Equatable {
    var date: Date
    var calendar: Calendar
    var foodEntries: [FoodEntry]
    var proteinProgress: MacroProgress
    var waterProgress: Double
    var calorieSummary: CalorieSummary
    var workoutSummary: TodayWorkoutSummary
    var activityContext: TodayActivityContext
    var trainingFrequencyPerWeek: Int
}

enum NextBestActionEngine {

    /// Hour (0–23) when the breakfast logging window ends (meal grouping).
    static let breakfastWindowEndHour = 11
    /// Hour when the lunch logging window ends (meal grouping).
    static let lunchWindowEndHour = 15
    /// Hour when the dinner logging window ends (meal grouping).
    static let dinnerWindowEndHour = 21
    /// Hour when lunch begins for next-best-action meal prompts.
    static let lunchHour = 12

    static let waterLowThreshold = TodayFocusBuilder.waterOnTrackThreshold
    static let proteinOnTrackThreshold = TodayFocusBuilder.proteinOnTrackThreshold
    static let defaultWaterAmountMl = 500

    static func resolve(_ input: NextBestActionInput) -> NextBestActionState {
        let hour = input.calendar.component(.hour, from: input.date)

        if input.foodEntries.isEmpty, hour < lunchHour {
            return logBreakfastAction()
        }

        if input.foodEntries.isEmpty {
            return logFirstMealAction()
        }

        if isProteinBehind(input) {
            return proteinAction(from: input)
        }

        if isWaterBehind(input) {
            return waterAction()
        }

        if shouldCompleteWorkout(input) {
            return completeWorkoutAction()
        }

        if isCaloriesCloseToLimit(input) {
            return keepDinnerLightAction()
        }

        if input.calorieSummary.isOverTarget {
            return focusHydrationRecoveryAction()
        }

        return allTargetsMetAction()
    }

    // MARK: - Eligibility

    static func isProteinBehind(_ input: NextBestActionInput) -> Bool {
        input.proteinProgress.progress < proteinOnTrackThreshold
    }

    static func isWaterBehind(_ input: NextBestActionInput) -> Bool {
        input.waterProgress < waterLowThreshold
    }

    static func shouldCompleteWorkout(_ input: NextBestActionInput) -> Bool {
        guard input.trainingFrequencyPerWeek > 0 else { return false }
        guard !hasWorkoutToday(input) else { return false }
        return isLikelyTrainingDay(
            frequency: input.trainingFrequencyPerWeek,
            date: input.date,
            calendar: input.calendar
        )
    }

    static func hasWorkoutToday(_ input: NextBestActionInput) -> Bool {
        input.workoutSummary.hasWorkout || (input.activityContext.appleHealthWorkoutCount ?? 0) > 0
    }

    static func isCaloriesCloseToLimit(_ input: NextBestActionInput) -> Bool {
        guard !input.calorieSummary.isOverTarget else { return false }
        return TodayMissionHeroFormatter.isNearTarget(input.calorieSummary)
    }

    static func isLikelyTrainingDay(
        frequency: Int,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        guard frequency > 0 else { return false }
        let weekday = calendar.component(.weekday, from: date)
        return frequency >= 3 ? weekday == 2 || weekday == 4 || weekday == 6 : weekday == 2
    }

    // MARK: - Action builders

    private static func makeAction(
        title: String,
        subtitle: String?,
        reason: TodayNextBestActionReason,
        primaryCTA: TodayNextBestActionCTA,
        secondaryCTAs: [TodayNextBestActionCTA] = []
    ) -> TodayNextBestActionState {
        let display = TodayNextActionFormatting.displayModel(
            for: TodayNextBestActionState(
                sectionTitle: FormaProductCopy.Today.NextAction.sectionTitle,
                title: title,
                subtitle: subtitle,
                reason: reason,
                primaryCTA: primaryCTA,
                secondaryCTAs: secondaryCTAs,
                accessibilityLabel: ""
            )
        )

        return TodayNextBestActionState(
            sectionTitle: display.sectionTitle,
            title: title,
            subtitle: subtitle,
            reason: reason,
            primaryCTA: primaryCTA,
            secondaryCTAs: secondaryCTAs,
            accessibilityLabel: display.accessibilityLabel
        )
    }

    private static func logBreakfastAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.logBreakfastTitle,
            subtitle: FormaProductCopy.Today.NextAction.logBreakfastSubtitle,
            reason: .logBreakfast,
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(.breakfast))
        )
    }

    private static func logFirstMealAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.logFirstMealTitle,
            subtitle: FormaProductCopy.Today.NextAction.logFirstMealSubtitle,
            reason: .logFirstMeal,
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal())
        )
    }

    private static func proteinAction(from input: NextBestActionInput) -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.eatProteinTitle,
            subtitle: FormaProductCopy.Today.NextAction.eatProteinSubtitle,
            reason: .eatProtein,
            primaryCTA: .scanFood,
            secondaryCTAs: [.logMeal(TodayCoachPrompt.logMeal())]
        )
    }

    private static func waterAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.hydrationBehindTitle,
            subtitle: FormaProductCopy.Today.NextAction.hydrationBehindSubtitle,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: defaultWaterAmountMl)
        )
    }

    private static func completeWorkoutAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.completeWorkoutTitle,
            subtitle: FormaProductCopy.Today.NextAction.completeWorkoutSubtitle,
            reason: .completeWorkout,
            primaryCTA: .logWorkout
        )
    }

    private static func keepDinnerLightAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.keepDinnerLightTitle,
            subtitle: FormaProductCopy.Today.NextAction.keepDinnerLightSubtitle,
            reason: .keepDinnerLight,
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(.dinner))
        )
    }

    private static func focusHydrationRecoveryAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.focusHydrationRecoveryTitle,
            subtitle: FormaProductCopy.Today.NextAction.focusHydrationRecoverySubtitle,
            reason: .focusHydrationRecovery,
            primaryCTA: .addWater(amountMl: defaultWaterAmountMl)
        )
    }

    private static func allTargetsMetAction() -> TodayNextBestActionState {
        makeAction(
            title: FormaProductCopy.Today.NextAction.allTargetsMetTitle,
            subtitle: FormaProductCopy.Today.NextAction.allTargetsMetSubtitle,
            reason: .allTargetsMet,
            primaryCTA: .none
        )
    }
}
