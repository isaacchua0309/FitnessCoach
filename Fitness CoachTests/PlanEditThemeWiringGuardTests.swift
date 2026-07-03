//
//  PlanEditThemeWiringGuardTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan theme wiring guardrails.
//

import XCTest

final class PlanEditThemeWiringGuardTests: XCTestCase {

    private let editPlanSourceFiles = [
        "Fitness Coach/Features/Plan/UI/PlanEditWizard.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditShell.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditSaveSuccessView.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditReviewCards.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditReviewStepView.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditActivityStepView.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditBodyBaselineStepView.swift",
        "Fitness Coach/Features/Plan/UI/PlanActivityExpertAdjustmentsCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanActivityLevelCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanActivityTargetPreviewCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanBodyBaselineSummaryCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanBodyMetricInputField.swift",
        "Fitness Coach/Features/Plan/UI/PlanGoalSelectionCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanGoalSelectionView.swift",
        "Fitness Coach/Features/Plan/UI/PlanGoalWeightInputField.swift",
        "Fitness Coach/Features/Plan/UI/PlanPaceOutcomeCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanProjectionCards.swift",
        "Fitness Coach/Features/Plan/UI/PlanTransformationSummaryCard.swift",
        "Fitness Coach/Features/Plan/UI/PlanEditSelectionChrome.swift",
        "Fitness Coach/Application/StateBuilders/Plan/PlanEditWizardStepGate.swift",
        "Fitness Coach/Domain/PlanCalculation/PlanNumericInputParser.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/PlanEditMotion.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanEditComponentModels.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanHeroCard.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanSelectableCard.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanMetricPill.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanProjectionCard.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanDifficultyBadge.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanTimelinePreview.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanMacroSummaryCard.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanWarningCard.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanSuccessCard.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanSegmentedControl.swift",
        "Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanInputField.swift",
        "Fitness Coach/Features/Settings/UI/WeightLossPaceSettingsView.swift",
        "Fitness Coach/DesignSystem/Tokens/FormaPlanTokens.swift"
    ]

    private let forbiddenPatterns = [
        "Color.blue",
        "Color.orange",
        "Color.red",
        "Color.gray",
        "Color.grey",
        "Color.white",
        "Color.black",
        ".foregroundColor(.white)",
        ".foregroundColor(.black)",
        ".foregroundStyle(.white)",
        ".foregroundStyle(.black)"
    ]

    func testEditPlanSourcesAvoidHardcodedSystemColors() throws {
        let repoRoot = try repoRootURL()

        for relativePath in editPlanSourceFiles {
            let url = repoRoot.appendingPathComponent(relativePath)
            let source = try String(contentsOf: url, encoding: .utf8)

            for pattern in forbiddenPatterns {
                XCTAssertFalse(
                    source.contains(pattern),
                    "Forbidden color pattern \(pattern) found in \(relativePath)"
                )
            }
        }
    }

    func testEditPlanSourcesAvoidRuntimeSemanticOpacityHacks() throws {
        let repoRoot = try repoRootURL()
        let forbiddenOpacityPatterns = [
            "planAccent.opacity",
            "planSuccess.opacity",
            "planWarning.opacity",
            "planCardBorder.opacity"
        ]

        for relativePath in editPlanSourceFiles where relativePath.hasSuffix(".swift") {
            let url = repoRoot.appendingPathComponent(relativePath)
            let source = try String(contentsOf: url, encoding: .utf8)

            for pattern in forbiddenOpacityPatterns {
                XCTAssertFalse(
                    source.contains(pattern),
                    "Runtime opacity hack \(pattern) found in \(relativePath)"
                )
            }
        }
    }

    func testEditPlanWizardUsesThemeReactiveModifier() throws {
        let repoRoot = try repoRootURL()
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Fitness Coach/Features/Plan/UI/PlanEditWizard.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".formaThemeReactive()"))
    }

    private func repoRootURL() throws -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
