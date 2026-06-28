//
//  PlanCopySafetyTests.swift
//  Fitness CoachTests
//
//  Forma — Plan dashboard copy safety: no Dynamic Calories, no stale onboarding handoffs.
//

import XCTest
@testable import Fitness_Coach

enum PlanCopySafetyPolicy {

    /// Returns the matched forbidden fragment when `text` violates Plan copy policy.
    static func forbiddenViolation(in text: String) -> String? {
        let lowered = text.lowercased()

        let alwaysForbidden = [
            "automatically adjust",
            "may automatically adjust",
            "calories may automatically",
            "dynamic calor",
            "plateau",
            "adaptive coach",
            "auto-adjust",
            "recalibrate your plan",
            "targets may change if",
            "activity shifts will recalibrate",
            "forma will adjust"
        ]

        for term in alwaysForbidden where lowered.contains(term) {
            return term
        }

        if lowered.contains("automatically change"),
           !lowered.contains("does not automatically change"),
           !lowered.contains("not automatically change"),
           !lowered.contains("will not auto-change"),
           !lowered.contains("won't change") {
            return "automatically change"
        }

        if lowered.range(of: #"\badaptive\b"#, options: .regularExpression) != nil {
            return "adaptive"
        }

        return nil
    }
}

final class PlanCopySafetyTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testPlanCopyAvoidsDynamicCaloriesAndAutomaticAdjustmentLanguage() {
        for sample in planCopySamples() {
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: sample),
                "Forbidden Plan copy in: \(sample)"
            )
        }
    }

    func testPlanDashboardCopyAvoidsOnboardingVersionReferences() {
        for sample in planDashboardCopySamples() {
            let lowered = sample.lowercased()
            XCTAssertFalse(lowered.contains("onboarding v1"))
            XCTAssertFalse(lowered.contains("onboarding v2"))
            XCTAssertFalse(lowered.contains("onboarding v3"))
        }
    }

    func testPlanDashboardCopyAvoidsStaleOnboardingHandoffLanguage() {
        for sample in planDashboardCopySamples() {
            let lowered = sample.lowercased()
            XCTAssertFalse(lowered.contains("during onboarding"), "Unexpected: \(sample)")
            XCTAssertFalse(lowered.contains("onboarding answers"), "Unexpected: \(sample)")
        }
    }

    func testPlanAdjustmentFooterUsesManualReviewCopy() {
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.editSafetyCopy,
            "You can adjust your plan anytime as your progress changes."
        )
    }

    func testPlanAssumptionsNoteDisclaimsAutoTargetChanges() {
        let note = FormaProductCopy.PlanMissionControl.planAssumptionsNote.lowercased()
        XCTAssertTrue(note.contains("won't change"))
    }

    func testAppleHealthPlanNoteDisclaimsAutoTargetChanges() {
        let note = FormaProductCopy.PlanMissionControl.appleHealthInsightsNote.lowercased()
        XCTAssertTrue(note.contains("does not automatically change"))
    }

    func testInitialPlanReasonUsesNeutralSetupLanguage() {
        XCTAssertEqual(
            FormaProductCopy.PlanMissionControl.planCreatedFromOnboarding,
            "Set when you first created your plan."
        )
    }

    private func planCopySamples() -> [String] {
        let mission = FormaProductCopy.PlanMissionControl.self
        let rationale = FormaProductCopy.PlanRationale.self
        let calculation = FormaProductCopy.PlanCalculation.self

        var samples: [String] = [
            mission.editSafetyCopy,
            mission.planAssumptionsNote,
            mission.appleHealthInsightsNote,
            mission.confidenceSafeCopy,
            mission.planCreatedFromOnboarding,
            mission.planUpdatedAfterEdit,
            mission.planUpdateReasonGoalChanged,
            mission.planUpdateReasonActivityChanged,
            mission.planUpdateReasonTargetsRegenerated,
            mission.weekEmptyState,
            mission.nextMilestoneEmpty,
            rationale.sectionTitle,
            rationale.seeCalculation,
            calculation.bodyDetailsSettingsFootnote,
            TrainingIntegrationCopy.planCardConnectedBody,
            TrainingIntegrationCopy.planCardDisconnectedBody,
            TrainingIntegrationCopy.planCardDeniedBody,
            TrainingIntegrationCopy.planCardUnavailableBody,
            TrainingIntegrationCopy.planIntegrationMessage(isAppleHealthConnected: true),
            TrainingIntegrationCopy.planIntegrationMessage(isAppleHealthConnected: false)
        ]

        samples += missionControlDashboardCopy(from: PlanMissionControlFixtures.loseDashboard)
        samples += missionControlDashboardCopy(from: PlanMissionControlFixtures.newUserDashboard)
        samples += missionControlDashboardCopy(from: PlanMissionControlFixtures.connectedDashboard)
        samples += trainingIntegrationCopySamples()
        samples += rationaleCopySamples()

        return samples
    }

    private func planDashboardCopySamples() -> [String] {
        planCopySamples() + [
            FormaProductCopy.EmptyState.planTitle,
            FormaProductCopy.EmptyState.planGetStarted
        ]
    }

    private func missionControlDashboardCopy(from dashboard: PlanMissionControlDashboard) -> [String] {
        [
            dashboard.mission.accessibilitySummary,
            dashboard.mission.headlineValue,
            dashboard.mission.statusCopy,
            dashboard.todayMission.progressCopy,
            dashboard.week.overallHeadline,
            dashboard.week.overallStatusCopy,
            dashboard.week.emptyStateCopy,
            dashboard.activityAssumptions.assumptionsNote,
            dashboard.activityAssumptions.accessibilitySummary,
            dashboard.rationale.summary,
            dashboard.rationale.accessibilitySummary,
            dashboard.rationale.sustainabilityNote,
            dashboard.confidence.safeCopy,
            dashboard.confidence.accessibilitySummary,
            dashboard.adjustment.editSafetyCopy,
            dashboard.adjustment.lastUpdateReasonCopy,
            dashboard.adjustment.accessibilitySummary,
            dashboard.nextMilestone.headline,
            dashboard.nextMilestone.detailCopy
        ].compactMap { $0 }
    }

    private func trainingIntegrationCopySamples() -> [String] {
        [
            PlanTrainingIntegrationPresentationBuilder.build(integrationState: .connected),
            PlanTrainingIntegrationPresentationBuilder.build(integrationState: .notConnected),
            PlanTrainingIntegrationPresentationBuilder.build(integrationState: .denied)
        ].flatMap { presentation in
            [
                presentation.sectionTitle,
                presentation.statusLabel,
                presentation.bodyCopy,
                presentation.accessibilitySummary,
                presentation.ctaTitle
            ].compactMap { $0 }
        }
    }

    private func rationaleCopySamples() -> [String] {
        [
            PlanMissionControlFixtures.loseProfile,
            PlanMissionControlFixtures.gainProfile,
            PlanMissionControlFixtures.maintainProfile
        ].flatMap { profile -> [String] in
            let built = PlanRationaleCopyBuilder.build(for: profile, referenceDate: referenceDate)
            return [
                built.summary,
                built.accessibilitySummary,
                built.sustainabilityNote
            ].compactMap { $0 }
        }
    }
}
