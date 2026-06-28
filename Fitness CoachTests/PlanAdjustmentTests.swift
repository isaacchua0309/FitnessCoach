//
//  PlanAdjustmentTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAdjustmentTests: XCTestCase {

    func testOnboardingFallbackWhenProfileNotEditedAfterCreation() {
        let adjustment = PlanMissionControlFixtures.newUserDashboard.adjustment

        XCTAssertEqual(
            adjustment.lastUpdateReasonCopy,
            FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding
        )
        XCTAssertEqual(adjustment.sectionTitle, "Plan adjustment")
        XCTAssertEqual(adjustment.adjustPlanTitle, "Adjust Plan")
    }

    func testEditedProfileShowsUpdatedAfterAdjustReason() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment

        XCTAssertEqual(
            adjustment.lastUpdateReasonCopy,
            FormaProductCopy.PlanMissionControl.planUpdatedAfterEdit
        )
    }

    func testExplicitReasonOverridesFallback() {
        let profile = PlanMissionControlFixtures.newUserProfile
        let reason = PlanAdjustmentStateBuilder.resolveLastUpdateReason(
            profile: profile,
            explicitReason: "Targets refreshed after a goal change."
        )

        XCTAssertEqual(reason, "Targets refreshed after a goal change.")
    }

    func testBlankExplicitReasonFallsBackToOnboardingCopy() {
        let profile = PlanMissionControlFixtures.newUserProfile
        let reason = PlanAdjustmentStateBuilder.resolveLastUpdateReason(
            profile: profile,
            explicitReason: "   "
        )

        XCTAssertEqual(
            reason,
            FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding
        )
    }

    func testAdjustmentCopyDoesNotPromiseFutureAutomation() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment
        let combined = (
            [adjustment.lastUpdateReasonCopy, adjustment.editSafetyCopy]
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("automatically adjust"))
        XCTAssertFalse(combined.contains("will adjust"))
        XCTAssertFalse(combined.contains("auto-change"))
    }

    func testAccessibilitySummaryIncludesLastUpdatedAndReason() {
        let adjustment = PlanMissionControlFixtures.newUserDashboard.adjustment

        XCTAssertTrue(adjustment.accessibilitySummary.contains("Plan adjustment"))
        XCTAssertTrue(adjustment.accessibilitySummary.contains(adjustment.lastUpdatedLabel))
        XCTAssertTrue(adjustment.accessibilitySummary.contains(adjustment.lastUpdateReasonCopy))
    }
}
