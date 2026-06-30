//
//  TodayCoachTipBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic Coach Tip from local Today state (no API).
//

import Foundation

struct TodayCoachTipInput: Equatable, Sendable {
    var date: Date
    var calendar: Calendar
    var calorieSummary: CalorieSummary
    var macroSummary: MacroSummary
    var waterSummary: WaterSummary
    var foodEntries: [FoodEntry]
}

enum TodayCoachTipBuilder {

    static let lunchProteinGapMinimumGrams = 25.0
    static let suggestedProteinMinimumGrams = 25.0
    static let suggestedProteinMaximumGrams = 45.0
    static let eveningHighCaloriesRatio = 0.45
    static let eveningStartHour = 17

    static func build(from input: TodayCoachTipInput) -> AICoachTipState {
        let hour = input.calendar.component(.hour, from: input.date)
        let caloriesRemaining = max(input.calorieSummary.remaining, 0)
        let proteinRemaining = max(input.macroSummary.protein.remaining, 0)

        if input.calorieSummary.isOverTarget || input.calorieSummary.remaining < 0 {
            return AICoachTipState(
                message: FormaProductCopy.Today.CoachTip.overTarget,
                coachPrefill: TodayCoachPrompt.reviewToday
            )
        }

        if allGoalsMet(input) {
            return AICoachTipState(
                message: FormaProductCopy.Today.CoachTip.allGoalsMet,
                coachPrefill: nil
            )
        }

        if isMorningWithoutBreakfast(hour: hour, foodEntries: input.foodEntries) {
            return AICoachTipState(
                message: FormaProductCopy.Today.CoachTip.morningNoBreakfast,
                coachPrefill: TodayCoachPrompt.logMeal(.breakfast)
            )
        }

        if isLunchProteinGap(
            hour: hour,
            proteinRemaining: proteinRemaining,
            proteinProgress: input.macroSummary.protein.progress,
            caloriesRemaining: caloriesRemaining
        ) {
            let proteinGrams = suggestedProteinGramsForLunch(
                proteinRemaining: proteinRemaining,
                foodEntries: input.foodEntries
            )
            return AICoachTipState(
                message: FormaProductCopy.Today.CoachTip.lunchProteinGap(
                    caloriesRemaining: TodayMissionHeroFormatting.calories(caloriesRemaining),
                    proteinGrams: proteinGrams
                ),
                coachPrefill: TodayCoachPrompt.logMeal(.lunch)
            )
        }

        if isEveningWithHighCaloriesRemaining(
            hour: hour,
            caloriesRemaining: caloriesRemaining,
            calorieTarget: input.calorieSummary.target
        ) {
            return AICoachTipState(
                message: FormaProductCopy.Today.CoachTip.eveningSimpleDinner,
                coachPrefill: TodayCoachPrompt.logMeal(.dinner)
            )
        }

        return AICoachTipState(
            message: fallbackMessage(for: input),
            coachPrefill: fallbackCoachPrefill(for: input)
        )
    }

    static func allGoalsMet(_ input: TodayCoachTipInput) -> Bool {
        guard input.calorieSummary.consumed > 0 else { return false }
        guard !input.calorieSummary.isOverTarget else { return false }
        guard input.macroSummary.protein.progress >= TodayFocusBuilder.proteinOnTrackThreshold else {
            return false
        }
        guard input.waterSummary.progress >= TodayFocusBuilder.waterOnTrackThreshold else {
            return false
        }
        return TodayDailySummaryScoring.caloriesStatus(input.calorieSummary) == .met
    }

    static func isMorningWithoutBreakfast(hour: Int, foodEntries: [FoodEntry]) -> Bool {
        hour < NextBestActionEngine.breakfastWindowEndHour
            && !NextBestActionEngine.hasLoggedMeal(.breakfast, in: foodEntries)
    }

    static func isLunchProteinGap(
        hour: Int,
        proteinRemaining: Double,
        proteinProgress: Double,
        caloriesRemaining: Int
    ) -> Bool {
        guard caloriesRemaining > 0 else { return false }
        guard proteinRemaining >= lunchProteinGapMinimumGrams else { return false }
        guard proteinProgress < TodayFocusBuilder.proteinOnTrackThreshold else { return false }
        guard hour >= NextBestActionEngine.breakfastWindowEndHour else { return false }
        guard hour < NextBestActionEngine.lunchWindowEndHour else { return false }
        return true
    }

    static func isEveningWithHighCaloriesRemaining(
        hour: Int,
        caloriesRemaining: Int,
        calorieTarget: Int
    ) -> Bool {
        guard hour >= eveningStartHour else { return false }
        guard calorieTarget > 0 else { return false }
        let ratio = Double(caloriesRemaining) / Double(calorieTarget)
        return ratio >= eveningHighCaloriesRatio
    }

    static func suggestedProteinGramsForLunch(
        proteinRemaining: Double,
        foodEntries: [FoodEntry]
    ) -> Int {
        var mealsRemaining = 0
        if !NextBestActionEngine.hasLoggedMeal(.lunch, in: foodEntries) {
            mealsRemaining += 1
        }
        if !NextBestActionEngine.hasLoggedMeal(.dinner, in: foodEntries) {
            mealsRemaining += 1
        }
        mealsRemaining = max(mealsRemaining, 1)

        let perMeal = proteinRemaining / Double(mealsRemaining)
        let clamped = min(
            max(perMeal, suggestedProteinMinimumGrams),
            suggestedProteinMaximumGrams
        )
        return Int(clamped.rounded())
    }

    private static func fallbackMessage(for input: TodayCoachTipInput) -> String {
        if input.macroSummary.protein.progress < TodayFocusBuilder.proteinOnTrackThreshold {
            return FormaProductCopy.Today.focusProteinLow
        }
        if input.waterSummary.progress < TodayFocusBuilder.waterOnTrackThreshold {
            return FormaProductCopy.Today.focusWaterLow
        }
        return FormaProductCopy.Today.defaultCoachNote
    }

    private static func fallbackCoachPrefill(for input: TodayCoachTipInput) -> String? {
        if input.macroSummary.protein.progress < TodayFocusBuilder.proteinOnTrackThreshold {
            return TodayCoachPrompt.logProtein
        }
        if input.waterSummary.progress < TodayFocusBuilder.waterOnTrackThreshold {
            return TodayCoachPrompt.logWater
        }
        return nil
    }
}
