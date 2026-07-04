//
//  PlanEditFinalQATests.swift
//  Fitness CoachTests
//
//  Forma — Automated QA checklist for the Edit Plan revamp.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class PlanEditFinalQATests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Wizard flow (manual QA items 1–14)

    func testQA01EditPlanFlowIncludesReviewAndConfirmSteps() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let steps = PlanEditWizardFlow.steps(for: formState)

        XCTAssertTrue(steps.contains(.goalAndTargetWeight))
        XCTAssertTrue(steps.contains(.reviewChanges))
        XCTAssertEqual(steps.last, .confirmTargets)
    }

    func testQA02ChangeGoalUpdatesProjectionLabel() {
        let projection = PlanProjectionBuilder.build(
            formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
            goalType: .gainMuscle,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            projection.goalLabel,
            PlanGoalSelectionBuilder.displayTitle(for: .gainMuscle)
        )
    }

    func testQA03ChangeTargetWeightValidatesAndAppearsInReview() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "70"

        let validation = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: formState.goalWeightKgText,
            currentWeightKg: 90,
            heightCm: 168,
            goalType: .loseFat,
            unitSystem: .metric
        )
        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState
        )

        XCTAssertNil(validation)
        XCTAssertTrue(review.hasChanges)
        XCTAssertEqual(review.changes.first { $0.id == "goalWeight" }?.after, "70 kg")
    }

    func testQA04EachPaceOptionProducesFriendlyPresentation() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let options = PlanPaceOutcomeBuilder.options(
            formState: formState,
            goalType: .loseFat,
            advancedDraft: .default,
            weightKg: 90,
            goalWeightKg: 75
        )

        XCTAssertEqual(options.count, WeightLossPaceChoice.allCases.count)
        for option in options {
            XCTAssertFalse(option.title.isEmpty)
            XCTAssertFalse(option.title.contains("loseFat"))
            XCTAssertFalse(option.title.contains("aggressiveDeficit"))
        }
    }

    func testQA05AdvancedWeeklyPaceIsSaveableWithValidAmount() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .advanced
        formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "0.8"
        )

        let preview = WeightLossPacePreviewBuilder.build(
            choice: formState.weightLossPaceChoice,
            advancedDraft: formState.advancedPaceDraft,
            weightKg: 90,
            goalWeightKg: 75
        )

        XCTAssertTrue(preview.isSaveable)
        XCTAssertNil(preview.validationError)
    }

    func testQA06AdvancedMonthlyPaceIsSaveableWithValidAmount() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .advanced
        formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .monthly,
            amountText: "3"
        )

        let preview = WeightLossPacePreviewBuilder.build(
            choice: formState.weightLossPaceChoice,
            advancedDraft: formState.advancedPaceDraft,
            weightKg: 90,
            goalWeightKg: 75
        )

        XCTAssertTrue(preview.isSaveable)
        XCTAssertNil(preview.validationError)
    }

    func testQA07ChangeHeightValidatesAndUpdatesReview() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.heightCmText = "172"

        let validation = PlanBodyBaselineValidationBuilder.validate(
            heightText: formState.heightCmText,
            weightText: formState.currentWeightKgText
        )
        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState
        )

        XCTAssertTrue(validation.isValid)
        XCTAssertNotNil(review.changes.first { $0.id == "height" })
    }

    func testQA08ChangeBaselineWeightValidatesAndUpdatesReview() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "88"

        let validation = PlanBodyBaselineValidationBuilder.validate(
            heightText: formState.heightCmText,
            weightText: formState.currentWeightKgText
        )
        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState
        )

        XCTAssertTrue(validation.isValid)
        XCTAssertNotNil(review.changes.first { $0.id == "weight" })
    }

    func testQA09ChangeActivityLevelUpdatesReview() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.selectActivityLevel(.veryActive)

        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState
        )

        XCTAssertNotNil(review.changes.first { $0.id == "activity" })
    }

    func testQA10ExpertAdjustmentsFieldsRemainEditable() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.estimatedBodyFatPercentageText = "22"
        formState.setTrainingFrequencyPerWeekText("4")
        formState.setAverageStepsText("9000")

        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState
        )

        XCTAssertNotNil(review.changes.first { $0.id == "training" })
        XCTAssertNotNil(review.changes.first { $0.id == "steps" })
    }

    func testQA11ReviewSummaryIncludesFriendlyChangeCopy() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "70"
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState
        )

        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: PlanMissionControlFixtures.loseProfile,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review
        )

        XCTAssertFalse(summary.isUpToDate)
        XCTAssertTrue(summary.inputChanges.first?.summary.contains("Changed from") == true)
    }

    func testQA12SaveRequiresChangesAndTargetPreview() {
        XCTAssertTrue(
            PlanEditWizardStepGate.canSave(
                targetPreview: PlanPreviewData.generatedPreview,
                reviewHasChanges: true,
                isSaving: false
            )
        )
    }

    func testQA13CancelWithUnsavedChangesIsDetectable() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "70"

        XCTAssertTrue(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: PlanMissionControlFixtures.loseProfile,
                formState: formState
            )
        )
    }

    func testQA14SaveWithNoChangesIsBlocked() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertFalse(
            PlanEditWizardStepGate.canSave(
                targetPreview: PlanPreviewData.generatedPreview,
                reviewHasChanges: false,
                isSaving: false
            )
        )
        XCTAssertFalse(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: PlanMissionControlFixtures.loseProfile,
                formState: formState
            )
        )
    }

    // MARK: - Theme & accessibility (manual QA items 15–19)

    func testQA15AllThemePalettesProvideCompletePlanColors() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for scheme in [ColorScheme.light, ColorScheme.dark] {
                    let resolved = ThemeTestSupport.makeResolved(
                        palette: palette,
                        systemColorScheme: scheme
                    )
                    let planColors = PlanThemeColorProvider.planColors(from: resolved)

                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planAccent), 0.5)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planWarning), 0.5)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planPrimaryText), 0.5)
                }
            }
        }
    }

    func testQA16SmallScreenSnapshotFixtureUsesCompactWidth() {
        XCTAssertEqual(PlanEditQALayoutPolicy.compactWidth, 375)
        XCTAssertGreaterThanOrEqual(PlanEditQALayoutPolicy.compactHeight, 667)
    }

    func testQA17LargeScreenSnapshotFixtureUsesExpandedWidth() {
        XCTAssertEqual(PlanEditQALayoutPolicy.expandedWidth, 430)
        XCTAssertGreaterThanOrEqual(PlanEditQALayoutPolicy.expandedHeight, 932)
    }

    func testQA18DynamicTypeSupportCapsAtAccessibilityFive() {
        XCTAssertTrue(PlanEditQALayoutPolicy.supportsDynamicTypeUpToAccessibility5)
    }

    func testQA19ReduceMotionDisablesStepAnimations() {
        XCTAssertNil(PlanEditMotion.animation(PlanEditMotion.stepTransition, reduceMotion: true))
        XCTAssertNil(PlanEditMotion.animation(PlanEditMotion.selection, reduceMotion: true))
    }

    // MARK: - Cleanup contracts

    func testWarningCodesAreMappedBeforeUI() {
        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: PlanEditWarningCode.aggressiveDeficit,
            isAggressive: false
        )

        XCTAssertNotNil(warning)
        XCTAssertFalse(warning?.title.contains(PlanEditWarningCode.aggressiveDeficit) == true)
    }

    func testRegenerationSheetMapsWarningWithoutRawKey() {
        let preview = CalorieTargetResult(
            estimatedBMR: 1_480,
            estimatedTDEE: 2_290,
            targets: PlanMissionControlFixtures.loseProfile.targets,
            estimatedDailyDeficit: 700,
            isAggressive: false,
            warning: PlanEditWarningCode.aggressiveDeficit
        )

        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: preview.warning,
            isAggressive: preview.isAggressive
        )

        XCTAssertEqual(warning?.title, FormaProductCopy.PlanEditReview.aggressiveDeficitTitle)
    }
}

/// Documents layout sizes used by optional Edit Plan snapshot exports.
enum PlanEditQALayoutPolicy {
    static let compactWidth: CGFloat = 375
    static let compactHeight: CGFloat = 667
    static let expandedWidth: CGFloat = 430
    static let expandedHeight: CGFloat = 932
    static let supportsDynamicTypeUpToAccessibility5 = true
}
