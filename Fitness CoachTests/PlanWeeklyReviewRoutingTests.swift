//
//  PlanWeeklyReviewRoutingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanWeeklyReviewRoutingTests: XCTestCase {

    func testWeeklyReviewEntryStepUsesReviewChanges() {
        XCTAssertEqual(PlanEditWizardFlow.weeklyReviewEntryStep, .reviewChanges)
    }

    func testWeeklyProgressReviewPlanCTAPrefersWeeklyReviewRoute() {
        var openedPlan = false
        var openedWeeklyReview = false
        let cta = WeeklyProgressCTA(
            id: "review",
            kind: .reviewPlan,
            title: "Review plan",
            subtitle: nil,
            accessibilityLabel: "Review plan"
        )

        WeeklyProgressCTAHandler.perform(
            cta,
            onOpenToday: nil,
            onOpenPlan: { openedPlan = true },
            onOpenPlanForWeeklyReview: { openedWeeklyReview = true }
        )

        XCTAssertTrue(openedWeeklyReview)
        XCTAssertFalse(openedPlan)
    }

    func testWeeklyProgressReviewPlanCTAFallsBackToPlanTab() {
        var openedPlan = false
        let cta = WeeklyProgressCTA(
            id: "review",
            kind: .reviewPlan,
            title: "Review plan",
            subtitle: nil,
            accessibilityLabel: "Review plan"
        )

        WeeklyProgressCTAHandler.perform(
            cta,
            onOpenToday: nil,
            onOpenPlan: { openedPlan = true }
        )

        XCTAssertTrue(openedPlan)
    }

    func testHoldSteadyCTAOpensPlanTabOnly() {
        var openedPlan = false
        var openedWeeklyReview = false
        let cta = WeeklyProgressCTA(
            id: "hold",
            kind: .holdSteady,
            title: "Hold steady",
            subtitle: nil,
            accessibilityLabel: "Hold steady"
        )

        WeeklyProgressCTAHandler.perform(
            cta,
            onOpenToday: nil,
            onOpenPlan: { openedPlan = true },
            onOpenPlanForWeeklyReview: { openedWeeklyReview = true }
        )

        XCTAssertTrue(openedPlan)
        XCTAssertFalse(openedWeeklyReview)
    }

    func testWeeklyReviewContextBuilderIncludesSafetyCopy() {
        let context = PlanEditWeeklyReviewContextBuilder.build(
            from: PlanMissionControlFixtures.activeUserDashboard
        )

        XCTAssertGreaterThan(context.currentCalorieTargetKcal, 0)
        XCTAssertEqual(
            context.safetyCopy,
            FormaProductCopy.PlanMissionControl.weeklyRecommendationSafetyCopy
        )
        XCTAssertFalse(context.accessibilitySummary.isEmpty)
    }
}
