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
    var weightLoggedToday: Bool
    var hasRecentWeight: Bool
    var activityContext: TodayActivityContext
    var hasDailyReview: Bool
}

enum NextBestActionEngine {

    /// Hour (0–23) when the breakfast logging window ends.
    static let breakfastWindowEndHour = 11
    /// Hour when the lunch logging window ends.
    static let lunchWindowEndHour = 15
    /// Hour when the dinner logging window ends.
    static let dinnerWindowEndHour = 21
    /// Hour when “review today” becomes relevant.
    static let reviewTodayStartHour = 19

    static let waterLowThreshold = TodayFocusBuilder.waterOnTrackThreshold
    static let proteinOnTrackThreshold = TodayFocusBuilder.proteinOnTrackThreshold
    /// Protein must trail the day clock by at least this much to count as “far below pace”.
    static let proteinPaceTolerance = 0.15

    static func resolve(_ input: NextBestActionInput) -> NextBestActionState {
        if let missedMeal = buildMissedMealAction(from: input) {
            return missedMeal
        }
        if isProteinFarBelowPace(input) {
            return proteinAction(from: input)
        }
        if input.waterProgress < waterLowThreshold {
            return waterAction(from: input)
        }
        if shouldSuggestLogWeight(input) {
            return weightAction(from: input)
        }
        if shouldConnectAppleHealth(input) {
            return connectHealthAction(from: input)
        }
        if shouldReviewToday(input) {
            return reviewTodayAction(from: input)
        }
        return onTrackAction(from: input)
    }

    // MARK: - Meal windows

    static func missedMealType(
        foodEntries: [FoodEntry],
        hour: Int
    ) -> MealType? {
        if hour >= dinnerWindowEndHour, !hasLoggedMeal(.dinner, in: foodEntries) {
            return .dinner
        }
        if hour >= lunchWindowEndHour, !hasLoggedMeal(.lunch, in: foodEntries) {
            return .lunch
        }
        if hour >= breakfastWindowEndHour, !hasLoggedMeal(.breakfast, in: foodEntries) {
            return .breakfast
        }
        return nil
    }

    static func hasLoggedMeal(_ mealType: MealType, in entries: [FoodEntry]) -> Bool {
        entries.contains { $0.mealType == mealType }
    }

    static func isProteinFarBelowPace(_ input: NextBestActionInput) -> Bool {
        guard !input.foodEntries.isEmpty else { return false }
        guard input.proteinProgress.progress < proteinOnTrackThreshold else { return false }

        let hour = input.calendar.component(.hour, from: input.date)
        let minute = input.calendar.component(.minute, from: input.date)
        let dayProgress = expectedDayProgress(hour: hour, minute: minute)
        return input.proteinProgress.progress + proteinPaceTolerance < dayProgress
    }

    static func expectedDayProgress(hour: Int, minute: Int) -> Double {
        let clampedHour = min(max(hour, 0), 23)
        let clampedMinute = min(max(minute, 0), 59)
        let minutes = clampedHour * 60 + clampedMinute
        return Double(minutes) / (24.0 * 60.0)
    }

    static func shouldSuggestLogWeight(_ input: NextBestActionInput) -> Bool {
        !input.weightLoggedToday && !input.hasRecentWeight
    }

    static func shouldConnectAppleHealth(_ input: NextBestActionInput) -> Bool {
        input.activityContext.trainingDataSource == .appleHealth
            && input.activityContext.trainingIntegration.showsConnectionGate
    }

    static func shouldReviewToday(_ input: NextBestActionInput) -> Bool {
        let hour = input.calendar.component(.hour, from: input.date)
        return hour >= reviewTodayStartHour
            && !input.foodEntries.isEmpty
            && !input.hasDailyReview
    }

    // MARK: - Action builders

    private static func buildMissedMealAction(from input: NextBestActionInput) -> NextBestActionState? {
        let hour = input.calendar.component(.hour, from: input.date)

        if input.foodEntries.isEmpty, hour < breakfastWindowEndHour {
            return NextBestActionState(
                title: FormaProductCopy.Today.NextAction.logFirstMealTitle,
                subtitle: FormaProductCopy.Today.NextAction.logFirstMealSubtitle,
                reason: .logFirstMeal,
                primaryCTA: .logMeal(TodayCoachPrompt.logMeal()),
                secondaryCTAs: []
            )
        }

        guard let mealType = missedMealType(foodEntries: input.foodEntries, hour: hour) else {
            return nil
        }

        return NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logMissedMealTitle(mealType),
            subtitle: FormaProductCopy.Today.NextAction.logMissedMealSubtitle(mealType),
            reason: .logMissedMeal(mealType),
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(mealType)),
            secondaryCTAs: []
        )
    }

    private static func proteinAction(from input: NextBestActionInput) -> NextBestActionState {
        let suggestedGrams = max(15, Int(input.proteinProgress.remaining.rounded()))
        return NextBestActionState(
            title: FormaProductCopy.Today.NextAction.eatProteinTitle(grams: suggestedGrams),
            subtitle: FormaProductCopy.Today.NextAction.eatProteinSubtitle,
            reason: .eatProtein,
            primaryCTA: .logMeal(TodayCoachPrompt.logProtein),
            secondaryCTAs: []
        )
    }

    private static func waterAction(from input: NextBestActionInput) -> NextBestActionState {
        let amountMl = 500
        return NextBestActionState(
            title: FormaProductCopy.Today.NextAction.drinkWaterTitle(amountMl: amountMl),
            subtitle: FormaProductCopy.Today.NextAction.addWaterSubtitle,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: amountMl),
            secondaryCTAs: []
        )
    }

    private static func weightAction(from input: NextBestActionInput) -> NextBestActionState {
        NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logWeightTitle,
            subtitle: FormaProductCopy.Today.NextAction.logWeightSubtitle,
            reason: .logWeight,
            primaryCTA: .logWeight,
            secondaryCTAs: []
        )
    }

    private static func connectHealthAction(from input: NextBestActionInput) -> NextBestActionState {
        NextBestActionState(
            title: FormaProductCopy.Today.NextAction.connectHealthTitle,
            subtitle: FormaProductCopy.Today.NextAction.connectHealthSubtitle,
            reason: .connectAppleHealth,
            primaryCTA: .openHealth,
            secondaryCTAs: []
        )
    }

    private static func reviewTodayAction(from input: NextBestActionInput) -> NextBestActionState {
        NextBestActionState(
            title: FormaProductCopy.Today.NextAction.reviewTodayTitle,
            subtitle: FormaProductCopy.Today.NextAction.reviewTodaySubtitle,
            reason: .reviewToday,
            primaryCTA: .reviewToday,
            secondaryCTAs: []
        )
    }

    private static func onTrackAction(from input: NextBestActionInput) -> NextBestActionState {
        NextBestActionState(
            title: FormaProductCopy.Today.NextAction.onTrackTitle,
            subtitle: FormaProductCopy.Today.NextAction.onTrackSubtitle,
            reason: .onTrack,
            primaryCTA: .none,
            secondaryCTAs: []
        )
    }
}
