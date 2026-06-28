//
//  CoachTipBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachTipBuilderTests: XCTestCase {

    func testMorningNoBreakfastTip() {
        let tip = buildTip(
            hour: 8,
            caloriesConsumed: 0,
            caloriesTarget: 1_800,
            proteinConsumed: 0,
            proteinTarget: 170,
            waterConsumedMl: 0,
            waterTargetMl: 3_500,
            foodEntries: []
        )

        XCTAssertEqual(tip.message, FormaProductCopy.Today.CoachTip.morningNoBreakfast)
        XCTAssertEqual(tip.coachPrefill, TodayCoachPrompt.logMeal(.breakfast))
    }

    func testLunchProteinGapTipUsesCaloriesRemainingAndProteinSuggestion() {
        let tip = buildTip(
            hour: 12,
            caloriesConsumed: 200,
            caloriesTarget: 1_800,
            proteinConsumed: 100,
            proteinTarget: 170,
            waterConsumedMl: 800,
            waterTargetMl: 3_500,
            foodEntries: [foodEntry(mealType: .breakfast)]
        )

        XCTAssertEqual(
            tip.message,
            FormaProductCopy.Today.CoachTip.lunchProteinGap(
                caloriesRemaining: TodayMissionHeroFormatting.calories(1_600),
                proteinGrams: 35
            )
        )
        XCTAssertEqual(tip.coachPrefill, TodayCoachPrompt.logMeal(.lunch))
    }

    func testEveningHighCaloriesRemainingTip() {
        let tip = buildTip(
            hour: 18,
            caloriesConsumed: 900,
            caloriesTarget: 1_800,
            proteinConsumed: 90,
            proteinTarget: 170,
            waterConsumedMl: 1_800,
            waterTargetMl: 3_500,
            foodEntries: [
                foodEntry(mealType: .breakfast),
                foodEntry(mealType: .lunch)
            ]
        )

        XCTAssertEqual(tip.message, FormaProductCopy.Today.CoachTip.eveningSimpleDinner)
        XCTAssertEqual(tip.coachPrefill, TodayCoachPrompt.logMeal(.dinner))
    }

    func testOverTargetTipIsNonPunitive() {
        let tip = buildTip(
            hour: 20,
            caloriesConsumed: 2_100,
            caloriesTarget: 1_800,
            proteinConsumed: 120,
            proteinTarget: 170,
            waterConsumedMl: 2_000,
            waterTargetMl: 3_500,
            foodEntries: [foodEntry(mealType: .dinner)],
            overrideOverTarget: true
        )

        XCTAssertEqual(tip.message, FormaProductCopy.Today.CoachTip.overTarget)
        XCTAssertEqual(tip.coachPrefill, TodayCoachPrompt.reviewToday)
        XCTAssertFalse(tip.message.lowercased().contains("panic"))
    }

    func testAllGoalsMetTip() {
        let tip = buildTip(
            hour: 19,
            caloriesConsumed: 1_750,
            caloriesTarget: 1_800,
            proteinConsumed: 165,
            proteinTarget: 170,
            waterConsumedMl: 3_200,
            waterTargetMl: 3_500,
            foodEntries: [
                foodEntry(mealType: .breakfast),
                foodEntry(mealType: .lunch),
                foodEntry(mealType: .dinner)
            ]
        )

        XCTAssertEqual(tip.message, FormaProductCopy.Today.CoachTip.allGoalsMet)
        XCTAssertNil(tip.coachPrefill)
    }

    func testBuilderWiresDeterministicTipWithoutDailyBrief() {
        let state = TodayDashboardFixtures.overTargetDay()

        XCTAssertEqual(state.aiCoachTip.message, FormaProductCopy.Today.CoachTip.overTarget)
    }

    // MARK: - Helpers

    private func buildTip(
        hour: Int,
        caloriesConsumed: Int,
        caloriesTarget: Int,
        proteinConsumed: Double,
        proteinTarget: Double,
        waterConsumedMl: Int,
        waterTargetMl: Int,
        foodEntries: [FoodEntry],
        overrideOverTarget: Bool? = nil
    ) -> AICoachTipState {
        let date = TodayDashboardFixtures.date(hour: hour)
        let overTarget = overrideOverTarget ?? (caloriesConsumed > caloriesTarget)

        return TodayCoachTipBuilder.build(
            from: TodayCoachTipInput(
                date: date,
                calendar: Calendar.current,
                calorieSummary: CalorieSummary(
                    consumed: caloriesConsumed,
                    target: caloriesTarget,
                    remaining: caloriesTarget - caloriesConsumed,
                    progress: caloriesTarget > 0 ? Double(caloriesConsumed) / Double(caloriesTarget) : 0,
                    isOverTarget: overTarget
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(
                        consumed: proteinConsumed,
                        target: proteinTarget,
                        remaining: max(proteinTarget - proteinConsumed, 0),
                        progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                    ),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: waterConsumedMl,
                    targetMl: waterTargetMl,
                    remainingMl: max(waterTargetMl - waterConsumedMl, 0),
                    progress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
                ),
                foodEntries: foodEntries
            )
        )
    }

    private func foodEntry(mealType: MealType) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: mealType,
            name: "Test meal",
            quantity: 1,
            unit: "serving",
            calories: 300,
            protein: 25,
            carbs: 20,
            fat: 10,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            createdAt: TodayDashboardFixtures.date(hour: 8),
            updatedAt: TodayDashboardFixtures.date(hour: 8)
        )
    }
}
