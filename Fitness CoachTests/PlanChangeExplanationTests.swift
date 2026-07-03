//
//  PlanChangeExplanationTests.swift
//  Fitness CoachTests
//
//  Forma — Human-readable plan change reasons.
//

import XCTest
@testable import Fitness_Coach

final class PlanChangeExplanationTests: XCTestCase {

    private let calendar = Calendar.current
    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testLastUpdatedLabelUsesTodayForSameDayEdits() {
        let label = PlanLastUpdatedLabelFormatter.label(
            for: PlanMissionControlFixtures.newUserProfile.updatedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertEqual(label, "Today")
    }

    func testLastUpdatedLabelUsesAbsoluteDateForOlderEdits() {
        let updatedAt = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let label = PlanLastUpdatedLabelFormatter.label(
            for: updatedAt,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(label, "Jun 1, 2026")
    }

    func testPlanUpdateReasonCopyMapsAllReasonCodes() {
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.planUpdateReason(.onboarding),
            FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding
        )
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.planUpdateReason(.goalChanged),
            FormaProductCopy.PlanMissionControl.planUpdateReasonGoalChanged
        )
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.planUpdateReason(.activityChanged),
            FormaProductCopy.PlanMissionControl.planUpdateReasonActivityChanged
        )
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.planUpdateReason(.targetsRegenerated),
            FormaProductCopy.PlanMissionControl.planUpdateReasonTargetsRegenerated
        )
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func testResolverDetectsTargetsRegeneratedWhenOnlyTargetsChange() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let update = UserProfileUpdate(targets: DailyLogServiceTestSupport.alternateTargets)

        XCTAssertEqual(
            PlanUpdateReasonResolver.resolve(baseline: baseline, update: update),
            .targetsRegenerated
        )
    }

    func testChangeExplanationCopyAvoidsDynamicCaloriesLanguage() {
        let reasons = [
            FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding,
            FormaProductCopy.PlanMissionControl.planUpdateReasonGoalChanged,
            FormaProductCopy.PlanMissionControl.planUpdateReasonActivityChanged,
            FormaProductCopy.PlanMissionControl.planUpdateReasonTargetsRegenerated,
            FormaProductCopy.PlanMissionControl.planUpdatedAfterEdit
        ]

        for reason in reasons {
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: reason),
                "Unsafe change explanation copy: \(reason)"
            )
        }
    }

    @MainActor
    func testUpdatePlanPersistsResolvedGoalChangedReason() async throws {
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
    }
}
