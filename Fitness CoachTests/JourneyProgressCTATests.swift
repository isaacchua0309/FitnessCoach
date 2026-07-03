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

    func testWeeklyTrainingLockedMapsToConnectAppleHealth() {
        XCTAssertEqual(
            JourneyCTARouter.weeklyTrainingCTA(training: .locked),
            .connectAppleHealth
        )
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
