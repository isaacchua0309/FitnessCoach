//
//  PlanAdjustmentTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanAdjustmentTests: XCTestCase {

    private let calendar = Calendar.current
    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    // MARK: - Onboarding fallback

    func testOnboardingCreatedPlanShowsOnboardingReason() {
        let adjustment = PlanMissionControlFixtures.newUserDashboard.adjustment

        XCTAssertEqual(
            adjustment.lastUpdateReasonCopy,
            FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding
        )
        XCTAssertEqual(adjustment.lastUpdatedLabel, "Last updated: Today")
        XCTAssertEqual(adjustment.sectionTitle, "Adjust Plan")
        XCTAssertEqual(adjustment.summaryRows.count, 4)
    }

    func testLegacyProfileWithoutStoredReasonFallsBackToOnboardingWhenUnedited() {
        var profile = PlanMissionControlFixtures.newUserProfile
        profile.lastPlanUpdateReason = nil

        let reason = PlanAdjustmentStateBuilder.resolveLastUpdateReason(profile: profile)

        XCTAssertEqual(reason, FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding)
    }

    // MARK: - Stored reasons

    func testGoalChangedReasonCopy() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment

        XCTAssertEqual(
            adjustment.lastUpdateReasonCopy,
            FormaProductCopy.PlanMissionControl.planUpdateReasonGoalChanged
        )
    }

    func testActivityChangedReasonCopy() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.lastPlanUpdateReason = .activityChanged

        let adjustment = PlanAdjustmentStateBuilder.build(
            profile: profile,
            planResult: nil,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            adjustment.lastUpdateReasonCopy,
            FormaProductCopy.PlanMissionControl.planUpdateReasonActivityChanged
        )
    }

    func testTargetsRegeneratedReasonCopy() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.lastPlanUpdateReason = .targetsRegenerated

        let adjustment = PlanAdjustmentStateBuilder.build(
            profile: profile,
            planResult: nil,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            adjustment.lastUpdateReasonCopy,
            FormaProductCopy.PlanMissionControl.planUpdateReasonTargetsRegenerated
        )
    }

    // MARK: - Relative last updated labels

    func testLastUpdatedLabelUsesYesterdayWhenProfileUpdatedYesterday() {
        var profile = PlanMissionControlFixtures.newUserProfile
        profile.updatedAt = calendar.date(byAdding: .day, value: -1, to: referenceDate)!

        let adjustment = PlanAdjustmentStateBuilder.build(
            profile: profile,
            planResult: nil,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(adjustment.lastUpdatedLabel, "Last updated: Yesterday")
    }

    func testLastUpdatedLabelUsesAbsoluteDateForOlderEdits() {
        var profile = PlanMissionControlFixtures.newUserProfile
        profile.updatedAt = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let adjustment = PlanAdjustmentStateBuilder.build(
            profile: profile,
            planResult: nil,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(adjustment.lastUpdatedLabel, "Last updated: Jun 1, 2026")
    }

    // MARK: - Reason resolver

    func testResolverPrefersGoalChangeOverActivityAndTargets() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let update = UserProfileUpdate(
            goalWeightKg: baseline.goalWeightKg - 2,
            activityLevel: .veryActive,
            targets: DailyLogServiceTestSupport.alternateTargets
        )

        XCTAssertEqual(
            PlanUpdateReasonResolver.resolve(baseline: baseline, update: update),
            .goalChanged
        )
    }

    func testResolverDetectsActivityChangeWhenGoalUnchanged() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let update = UserProfileUpdate(
            activityLevel: .sedentary,
            targets: DailyLogServiceTestSupport.alternateTargets
        )

        XCTAssertEqual(
            PlanUpdateReasonResolver.resolve(baseline: baseline, update: update),
            .activityChanged
        )
    }

    func testResolverDetectsTargetsRegeneratedWhenOnlyTargetsChange() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let update = UserProfileUpdate(targets: DailyLogServiceTestSupport.alternateTargets)

        XCTAssertEqual(
            PlanUpdateReasonResolver.resolve(baseline: baseline, update: update),
            .targetsRegenerated
        )
    }

    // MARK: - Guardrails

    func testAdjustmentCopyDoesNotPromiseFutureAutomation() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment
        let combined = (
            [adjustment.lastUpdateReasonCopy, adjustment.editSafetyCopy]
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("automatically adjust"))
        XCTAssertFalse(combined.contains("auto-change"))
        XCTAssertFalse(combined.contains("dynamic calor"))
        XCTAssertFalse(combined.contains("plateau"))
    }

    func testAdjustmentFooterEncouragesManualReview() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment

        XCTAssertEqual(
            adjustment.editSafetyCopy,
            "You can adjust your plan anytime as your progress changes."
        )
    }

    func testAccessibilitySummaryIncludesLastUpdatedAndReason() {
        let adjustment = PlanMissionControlFixtures.newUserDashboard.adjustment

        XCTAssertTrue(adjustment.accessibilitySummary.contains("Last updated: Today"))
        XCTAssertTrue(adjustment.accessibilitySummary.contains("Reason:"))
        XCTAssertTrue(adjustment.accessibilitySummary.contains(adjustment.lastUpdateReasonCopy))
        XCTAssertTrue(adjustment.accessibilitySummary.contains("Current:"))
    }

    @MainActor
    func testCreateProfileStoresOnboardingReason() throws {
        let container = try AppContainer(inMemory: true)
        _ = try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let profile = try XCTUnwrap(container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.lastPlanUpdateReason, .onboarding)
    }

    @MainActor
    func testUpdatePlanPersistsGoalChangedReason() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: nil)
        try harness.seedProfile()

        let baseline = try XCTUnwrap(harness.profileService.getCurrentProfile())
        var update = UserProfileUpdate(
            goalWeightKg: baseline.goalWeightKg - 3,
            targets: DailyLogServiceTestSupport.alternateTargets
        )
        update.lastPlanUpdateReason = PlanUpdateReasonResolver.resolve(baseline: baseline, update: update)

        let profile = try harness.actionCenter.updatePlan(update)

        XCTAssertEqual(profile.lastPlanUpdateReason, .goalChanged)
        XCTAssertEqual(profile.goalWeightKg, baseline.goalWeightKg - 3)
    }
}
