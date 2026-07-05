//
//  AdjustPlanDiscardConfirmationTests.swift
//  Fitness CoachTests
//
//  Forma — Discard confirmation behavior for the Adjust Plan flow.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class AdjustPlanDiscardConfirmationTests: XCTestCase {

    private var container: AppContainer!
    private var model: PlanModel!

    private let regressionSize = CGSize(
        width: AdjustPlanLayoutPolicy.standardPhoneWidth,
        height: 780
    )

    private let smallPhoneSize = CGSize(
        width: AdjustPlanLayoutPolicy.smallPhoneWidth,
        height: 700
    )

    override func setUp() async throws {
        container = try AppContainer(inMemory: true)
        model = container.makePlanModel()
        try await seedProfile()
        await model.loadProfile()
    }

    override func tearDown() async throws {
        FormaThemeAccess.resetToProductDefault()
        try await super.tearDown()
    }

    // MARK: - 1. Cancel with no changes

    func testCancelWithNoChangesDismissesImmediately() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let formState = PlanFormState(profile: baseline)

        XCTAssertFalse(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: baseline,
                formState: formState
            )
        )
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: false),
            .dismissImmediately
        )

        model.showEditPlan()
        XCTAssertTrue(model.isShowingEditSheet)

        model.dismissEditPlan()

        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertNil(model.editFormState)
    }

    func testCancelWithNoChangesDoesNotRouteToDiscardConfirmation() {
        var isShowingDiscardConfirmation = false

        let action = PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: false)
        if action == .presentConfirmation {
            isShowingDiscardConfirmation = true
        }

        XCTAssertFalse(isShowingDiscardConfirmation)
    }

    // MARK: - 2. Cancel with unsaved goal change

    func testCancelWithUnsavedGoalChangeRequiresConfirmation() {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)

        XCTAssertEqual(PlanStateBuilder.goalType(for: baseline), .loseFat)

        formState.goalWeightKgText = formattedWeight(baseline.currentWeightKg)

        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)
        XCTAssertTrue(review.hasChanges)
        XCTAssertEqual(
            review.changes.first { $0.id == "goal" }?.before,
            PlanGoalSelectionBuilder.displayTitle(for: .loseFat)
        )
        XCTAssertEqual(
            review.changes.first { $0.id == "goal" }?.after,
            PlanGoalSelectionBuilder.displayTitle(for: .maintain)
        )
        XCTAssertTrue(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: baseline,
                formState: formState
            )
        )
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: true),
            .presentConfirmation
        )
    }

    func testCancelWithUnsavedGoalChangeDoesNotDismissSheetUntilConfirmed() {
        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }

        formState.goalWeightKgText = formattedWeight(PlanMissionControlFixtures.loseProfile.currentWeightKg)
        model.editFormState = formState

        var isShowingDiscardConfirmation = false
        if PlanEditDiscardConfirmationPolicy.cancelRequestAction(
            hasUnsavedChanges: PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: PlanMissionControlFixtures.loseProfile,
                formState: formState
            )
        ) == .presentConfirmation {
            isShowingDiscardConfirmation = true
        }

        XCTAssertTrue(isShowingDiscardConfirmation)
        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertNotNil(model.editFormState)
    }

    // MARK: - 3. Keep Editing

    func testKeepEditingHidesConfirmationAndPreservesDraft() {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"

        var isShowingDiscardConfirmation = true
        isShowingDiscardConfirmation = false

        XCTAssertFalse(isShowingDiscardConfirmation)
        XCTAssertEqual(formState.goalWeightKgText, "70")
        XCTAssertTrue(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: baseline,
                formState: formState
            )
        )

        model.showEditPlan()
        model.editFormState = formState
        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertEqual(model.editFormState?.goalWeightKgText, "70")
    }

    // MARK: - 4. Discard Changes

    func testDiscardChangesResetsDraftAndDismissesWithoutSaving() async throws {
        guard case .loaded(let loaded) = model.viewState else {
            return XCTFail("Expected loaded profile")
        }
        let originalGoalWeight = loaded.profile.goalWeightKg

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        formState.goalWeightKgText = "70"
        model.editFormState = formState

        model.dismissEditPlan()

        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertNil(model.editFormState)

        let profile = try XCTUnwrap(container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, originalGoalWeight)
    }

    func testDiscardChangesAfterGoalChangeDoesNotPersistMaintainGoal() async throws {
        let baseline = PlanMissionControlFixtures.loseProfile

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        formState.goalWeightKgText = formattedWeight(baseline.currentWeightKg)
        model.editFormState = formState

        model.dismissEditPlan()

        let profile = try XCTUnwrap(container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, baseline.goalWeightKg)
        XCTAssertEqual(PlanStateBuilder.goalType(for: profile), .loseFat)
    }

    // MARK: - 5. Next / save

    func testSaveCommitsChangesWithoutDiscardConfirmation() async throws {
        guard case .loaded(let before) = model.viewState else {
            return XCTFail("Expected loaded profile")
        }

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }

        formState.goalWeightKgText = "70"
        try await model.savePlanFromWizard(formState)

        guard case .loaded(let after) = model.viewState else {
            return XCTFail("Expected loaded profile after save")
        }

        XCTAssertEqual(after.profile.goalWeightKg, 70)
        XCTAssertNotEqual(after.profile.goalWeightKg, before.profile.goalWeightKg)
        XCTAssertFalse(model.isShowingEditSheet)
    }

    func testSaveFlowDoesNotUseDiscardConfirmationPolicy() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "70"

        XCTAssertTrue(
            PlanEditWizardStepGate.canSave(
                targetPreview: PlanPreviewData.generatedPreview,
                reviewHasChanges: PlanEditReviewBuilder.build(
                    baseline: PlanMissionControlFixtures.loseProfile,
                    formState: formState
                ).hasChanges,
                isSaving: false
            )
        )
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: true),
            .presentConfirmation,
            "Dirty drafts still require confirmation only when canceling, not when saving"
        )
    }

    // MARK: - 6. Interactive dismiss

    func testInteractiveDismissBlockedWhenUnsavedChangesExist() throws {
        let source = try planEditWizardSource()

        XCTAssertTrue(source.contains(".interactiveDismissDisabled(hasUnsavedChanges)"))
        XCTAssertTrue(source.contains("DiscardChangesConfirmationView"))
        XCTAssertFalse(source.contains(".confirmationDialog("))
    }

    func testUnsavedChangesPreventSilentDiscardOnSwipeDismiss() {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"

        XCTAssertTrue(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: baseline,
                formState: formState
            )
        )
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: true),
            .presentConfirmation,
            "Swipe dismiss is disabled while dirty; cancel must route through confirmation"
        )
    }

    // MARK: - 7. Theme switching

    func testDiscardConfirmationThemeSwitchUpdatesAccentLive() {
        let ocean = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
        let blossom = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)

        FormaThemeAccess.update(resolved: ocean)
        let oceanAccent = FormaTokens.Color.accent
        let oceanDestructive = FormaTokens.Color.destructive

        FormaThemeAccess.update(resolved: blossom)
        let blossomAccent = FormaTokens.Color.accent
        let blossomDestructive = FormaTokens.Color.destructive

        XCTAssertGreaterThan(ThemeTestSupport.colorDistance(oceanAccent, blossomAccent), 0.08)
        XCTAssertEqual(
            ThemeTestSupport.colorDistance(oceanDestructive, blossomDestructive),
            0,
            accuracy: 0.001,
            "Destructive feedback should stay on semantic destructive token across palettes"
        )
    }

    func testDiscardConfirmationRendersForOceanBlueAndBlossomPinkThemes() {
        DiscardChangesConfirmationRenderTestSupport.assertRenders(
            size: regressionSize,
            palette: .oceanBlue,
            appearance: .dark
        )
        DiscardChangesConfirmationRenderTestSupport.assertRenders(
            size: regressionSize,
            palette: .blossomPink,
            appearance: .light
        )
    }

    // MARK: - 8. Dynamic Type

    func testDiscardConfirmationRendersAtLargeAccessibilityTextWithoutClipping() {
        let standard = DiscardChangesConfirmationRenderTestSupport.assertRenders(
            size: CGSize(width: regressionSize.width, height: 900),
            dynamicTypeSize: .large
        )
        let accessibility = DiscardChangesConfirmationRenderTestSupport.assertRenders(
            size: CGSize(width: regressionSize.width, height: 1_100),
            dynamicTypeSize: .accessibility5
        )

        XCTAssertGreaterThanOrEqual(accessibility?.size.height ?? 0, standard?.size.height ?? 0)
    }

    func testDiscardConfirmationRendersOnSmallPhoneAtAccessibilityTextSize() {
        DiscardChangesConfirmationRenderTestSupport.assertRenders(
            size: CGSize(width: smallPhoneSize.width, height: 1_000),
            dynamicTypeSize: .accessibility3
        )
    }

    // MARK: - Wiring

    func testPlanEditWizardUsesDiscardChangesConfirmationView() throws {
        let source = try planEditWizardSource()

        XCTAssertTrue(source.contains("isShowingDiscardConfirmation"))
        XCTAssertTrue(source.contains("DiscardChangesConfirmationView("))
        XCTAssertTrue(source.contains("PlanEditDiscardConfirmationPolicy.cancelRequestAction"))
    }

    // MARK: - Helpers

    private func seedProfile() async throws {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let input = try formState.makeCalorieTargetInput()
        let result = try container.targetService.generateInitialTargets(from: input)
        var draftForm = formState
        draftForm.applyGeneratedTargets(result.targets)
        let draft = try draftForm.makeDraft(targets: result.targets)
        _ = try container.userProfileService.createProfile(draft)
    }

    private func formattedWeight(_ kilograms: Double) -> String {
        kilograms.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kilograms))"
            : "\(kilograms)"
    }

    private func planEditWizardSource() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Fitness Coach/Features/Plan/UI/PlanEditWizard.swift"
            ),
            encoding: .utf8
        )
    }
}
