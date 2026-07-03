//
//  PlanEditCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan copy guardrails against raw IDs and engineering labels.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditCopyGuardrailTests: XCTestCase {

    func testEditPlanCopyAvoidsRawEnumKeysAndEngineeringLabels() {
        for sample in editPlanCopySamples() {
            let lowered = sample.lowercased()
            XCTAssertFalse(lowered.contains("aggressivedeficit"))
            XCTAssertFalse(lowered.contains("losefat"))
            XCTAssertFalse(lowered.contains("gainmuscle"))
            XCTAssertFalse(lowered.contains("expert adjustments"))
            XCTAssertFalse(lowered.contains("forma computes"))
            XCTAssertFalse(lowered.contains("no plan inputs changed"))
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: sample),
                "Forbidden Plan copy in: \(sample)"
            )
        }
    }

    func testGoalDisplayTitlesAvoidRawEnumIDs() {
        for goalType in PlanGoalType.allCases {
            let title = PlanGoalSelectionBuilder.displayTitle(for: goalType)
            XCTAssertFalse(title.contains("loseFat"))
            XCTAssertFalse(title == goalType.rawValue)
        }
    }

    func testTimelineCopyStripsLegacyAndCurrentFinishPrefixes() {
        XCTAssertEqual(
            PlanEditTimelineCopy.monthYearDisplay(fromCompletionLabel: "Estimated finish: March 2026."),
            "March 2026"
        )
        XCTAssertEqual(
            PlanEditTimelineCopy.monthYearDisplay(fromCompletionLabel: "On track for March 2026."),
            "March 2026"
        )
    }

    private func editPlanCopySamples() -> [String] {
        let goal = FormaProductCopy.PlanEditGoal.self
        let target = FormaProductCopy.PlanEditTarget.self
        let body = FormaProductCopy.PlanEditBodyBaseline.self
        let activity = FormaProductCopy.PlanEditActivity.self
        let review = FormaProductCopy.PlanEditReview.self
        let hero = FormaProductCopy.PlanEditHero.self
        let projection = FormaProductCopy.PlanProjection.self
        let difficulty = FormaProductCopy.PlanEditDifficulty.self
        let common = FormaProductCopy.PlanEditCommon.self
        let save = FormaProductCopy.PlanEditSave.self

        return [
            goal.sectionTitle,
            goal.loseFatTitle,
            goal.loseFatExplanation,
            goal.loseFatOutcome,
            goal.maintainTitle,
            goal.maintainExplanation,
            goal.maintainOutcome,
            goal.gainMuscleTitle,
            goal.gainMuscleExplanation,
            goal.gainMuscleOutcome,
            target.paceTitle,
            target.paceGentleSubtitle,
            target.paceAggressiveTitle,
            body.coachingLine,
            body.maintenanceAtBaseline("2,000 kcal/day"),
            body.targetAdjustedFromBaseline,
            activity.expertTitle,
            activity.expertSubtitle,
            activity.targetPreviewTitle,
            activity.macroTargetsNote,
            activity.previewUnavailable,
            review.planUpToDateHeadline,
            review.aggressiveDeficitTitle,
            review.aggressiveDeficitBody,
            review.friendlyChangeSummary(before: "70 kg", after: "68 kg"),
            hero.shellTitle,
            hero.motivationalFatLoss,
            hero.totalChangeToTarget("5 kg"),
            hero.estimatedFinish("April 2026"),
            projection.incompleteCalculation,
            projection.energyBalanceLabel,
            projection.sustainabilityOk,
            difficulty.fasterCut,
            common.sexRequiredNote,
            save.todayTargetsRegenerated
        ]
    }
}
