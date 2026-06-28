//
//  JourneyProgressCTATests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyProgressCTATests: XCTestCase {

    func testLogWeightCTAUsesCoachPrefill() {
        var capturedPrefill: String?
        JourneyCTAHandler.perform(
            .logWeight,
            onOpenCoach: { capturedPrefill = $0 },
            onOpenPlan: nil
        )

        XCTAssertEqual(capturedPrefill, TodayCoachPrompt.logWeight)
    }

    func testLogFoodCTAUsesCoachPrefill() {
        var capturedPrefill: String?
        JourneyCTAHandler.perform(
            .logFood,
            onOpenCoach: { capturedPrefill = $0 },
            onOpenPlan: nil
        )

        XCTAssertEqual(capturedPrefill, TodayCoachPrompt.logMeal())
    }

    func testLogWaterCTAUsesCoachPrefill() {
        var capturedPrefill: String?
        JourneyCTAHandler.perform(
            .logWater,
            onOpenCoach: { capturedPrefill = $0 },
            onOpenPlan: nil
        )

        XCTAssertEqual(capturedPrefill, TodayCoachPrompt.logWater)
    }

    func testHealthLockedCTADoesNotCrashWithoutPlanHandler() {
        XCTAssertNoThrow {
            JourneyCTAHandler.perform(
                .connectAppleHealth,
                onOpenCoach: nil,
                onOpenPlan: nil
            )
        }
    }

    func testHealthLockedCTAOpensPlanWhenHandlerProvided() {
        var openedPlan = false
        JourneyCTAHandler.perform(
            .connectAppleHealth,
            onOpenCoach: nil,
            onOpenPlan: { openedPlan = true }
        )

        XCTAssertTrue(openedPlan)
    }

    func testHabitSuggestionMapsWaterToCoachWaterPrefill() {
        let cta = JourneyCTARouter.habitSuggestionCTA(
            weakestKind: .water,
            isAppleHealthConnected: true
        )

        XCTAssertEqual(cta, .logWater)
        XCTAssertEqual(cta?.coachPrefill, TodayCoachPrompt.logWater)
    }

    func testHabitSuggestionMapsFoodLoggingToCoachMealPrefill() {
        let cta = JourneyCTARouter.habitSuggestionCTA(
            weakestKind: .foodLogging,
            isAppleHealthConnected: true
        )

        XCTAssertEqual(cta, .logFood)
        XCTAssertEqual(cta?.coachPrefill, TodayCoachPrompt.logMeal())
    }

    func testHabitSuggestionMapsWeightLoggingToCoachWeightPrefill() {
        let cta = JourneyCTARouter.habitSuggestionCTA(
            weakestKind: .weightLogging,
            isAppleHealthConnected: true
        )

        XCTAssertEqual(cta, .logWeight)
        XCTAssertEqual(cta?.coachPrefill, TodayCoachPrompt.logWeight)
    }

    func testWeeklyTrainingLockedMapsToConnectAppleHealth() {
        XCTAssertEqual(
            JourneyCTARouter.weeklyTrainingCTA(training: .locked),
            .connectAppleHealth
        )
    }

    func testDetailedAnalyticsWithoutChartOffersLogWeightCTA() {
        let analytics = JourneyDetailedAnalyticsState(
            isCollapsedByDefault: true,
            nutritionSummary: ProgressNutritionSummary(
                loggedDays: 3,
                averageCalories: 1_800,
                averageProtein: 120,
                averageCarbs: 150,
                averageFat: 55,
                averageFiber: nil
            ),
            waterSummary: ProgressWaterSummary(
                loggedDays: 3,
                averageWaterMl: 2_000,
                averageWaterTargetMl: 2_500,
                consistencyPercent: 0.5
            ),
            trainingDisplay: .hidden,
            weightChartPoints: [],
            weightTrendInterpretation: FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.insufficientData,
            showsWeightChart: false,
            weightLogCTA: .logWeight
        )

        XCTAssertFalse(analytics.showsWeightChart)
        XCTAssertEqual(analytics.weightLogCTA, .logWeight)
        XCTAssertTrue(analytics.isCollapsedByDefault)
    }

    func testJourneyCTADoesNotMutateThroughHandler() {
        var coachCalls = 0
        var planCalls = 0

        JourneyCTAHandler.perform(.logWeight, onOpenCoach: { _ in coachCalls += 1 }, onOpenPlan: { planCalls += 1 })
        JourneyCTAHandler.perform(.updateGoal, onOpenCoach: { _ in coachCalls += 1 }, onOpenPlan: { planCalls += 1 })

        XCTAssertEqual(coachCalls, 1)
        XCTAssertEqual(planCalls, 1)
    }
}
