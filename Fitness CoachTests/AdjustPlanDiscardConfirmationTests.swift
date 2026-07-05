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

    private let baseline = PlanMissionControlFixtures.loseProfile

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

    func testCase01_CancelWithNoChangesDismissesImmediatelyWithoutConfirmation() {
        let formState = PlanFormState(profile: baseline)

        XCTAssertFalse(hasUnsavedChanges(formState: formState))

        var confirmationState = PlanEditDiscardConfirmationState()
        XCTAssertEqual(
            confirmationState.handleCancelRequest(hasUnsavedChanges: hasUnsavedChanges(formState: formState)),
            .dismissImmediately
        )
        XCTAssertFalse(confirmationState.isShowingConfirmation)

        model.showEditPlan()
        model.dismissEditPlan()

        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertNil(model.editFormState)
    }

    // MARK: - 2. Cancel with unsaved goal change

    func testCase02_CancelWithUnsavedGoalChangeShowsConfirmationWithoutDismissing() {
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = formattedWeight(baseline.currentWeightKg)

        XCTAssertEqual(PlanStateBuilder.goalType(for: baseline), .loseFat)
        XCTAssertEqual(PlanStateBuilder.goalType(for: profileSnapshot(from: formState)), .maintain)

        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)
        XCTAssertEqual(
            review.changes.first { $0.id == "goal" }?.before,
            PlanGoalSelectionBuilder.displayTitle(for: .loseFat)
        )
        XCTAssertEqual(
            review.changes.first { $0.id == "goal" }?.after,
            PlanGoalSelectionBuilder.displayTitle(for: .maintain)
        )

        var confirmationState = PlanEditDiscardConfirmationState()
        XCTAssertEqual(
            confirmationState.handleCancelRequest(hasUnsavedChanges: hasUnsavedChanges(formState: formState)),
            .presentConfirmation
        )
        XCTAssertTrue(confirmationState.isShowingConfirmation)

        model.showEditPlan()
        model.editFormState = formState

        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertNotNil(model.editFormState)
    }

    // MARK: - 3. Keep Editing

    func testCase03_KeepEditingHidesConfirmationAndPreservesDraftOnAdjustPlan() {
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"

        var confirmationState = PlanEditDiscardConfirmationState()
        _ = confirmationState.handleCancelRequest(hasUnsavedChanges: hasUnsavedChanges(formState: formState))
        XCTAssertTrue(confirmationState.isShowingConfirmation)

        confirmationState.keepEditing()

        XCTAssertFalse(confirmationState.isShowingConfirmation)
        XCTAssertEqual(formState.goalWeightKgText, "70")
        XCTAssertTrue(hasUnsavedChanges(formState: formState))

        model.showEditPlan()
        model.editFormState = formState

        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertEqual(model.editFormState?.goalWeightKgText, "70")
    }

    // MARK: - 4. Discard Changes

    func testCase04_DiscardChangesResetsDraftDismissesFlowAndLeavesSavedPlanUnchanged() async throws {
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

        var confirmationState = PlanEditDiscardConfirmationState()
        _ = confirmationState.handleCancelRequest(hasUnsavedChanges: true)
        confirmationState.dismissConfirmation()

        XCTAssertFalse(confirmationState.isShowingConfirmation)

        model.dismissEditPlan()

        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertNil(model.editFormState)

        let profile = try XCTUnwrap(container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, originalGoalWeight)
        XCTAssertEqual(PlanStateBuilder.goalType(for: profile), .loseFat)
    }

    func testCase04_DiscardChangesAfterMaintainGoalDraftDoesNotPersistGoalChange() async throws {
        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        formState.goalWeightKgText = formattedWeight(baseline.currentWeightKg)
        model.editFormState = formState

        var confirmationState = PlanEditDiscardConfirmationState()
        _ = confirmationState.handleCancelRequest(hasUnsavedChanges: true)
        confirmationState.dismissConfirmation()
        model.dismissEditPlan()

        let profile = try XCTUnwrap(container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, baseline.goalWeightKg)
        XCTAssertEqual(PlanStateBuilder.goalType(for: profile), .loseFat)
    }

    // MARK: - 5. Next / save

    func testCase05_SaveCommitsDraftChangesWithoutDiscardConfirmation() async throws {
        guard case .loaded(let before) = model.viewState else {
            return XCTFail("Expected loaded profile")
        }

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        formState.goalWeightKgText = "70"

        var confirmationState = PlanEditDiscardConfirmationState()
        XCTAssertFalse(confirmationState.isShowingConfirmation)

        try await model.savePlanFromWizard(formState)

        guard case .loaded(let after) = model.viewState else {
            return XCTFail("Expected loaded profile after save")
        }

        XCTAssertEqual(after.profile.goalWeightKg, 70)
        XCTAssertNotEqual(after.profile.goalWeightKg, before.profile.goalWeightKg)
        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertFalse(confirmationState.isShowingConfirmation)
    }

    // MARK: - 6. Interactive dismiss

    func testCase06_InteractiveDismissIsDisabledWhileDraftHasUnsavedChanges() throws {
        let source = try planEditWizardSource()

        XCTAssertTrue(source.contains(".interactiveDismissDisabled(hasUnsavedChanges)"))
        XCTAssertTrue(source.contains("DiscardChangesConfirmationView"))
        XCTAssertFalse(source.contains(".confirmationDialog("))
    }

    func testCase06_UnsavedChangesRequireConfirmationInsteadOfSilentDiscard() {
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"

        XCTAssertTrue(hasUnsavedChanges(formState: formState))
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: true),
            .presentConfirmation
        )
    }

    // MARK: - 7. Theme switching

    func testCase07_DiscardConfirmationAccentUpdatesWhenThemeChanges() {
        let ocean = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
        let blossom = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)

        FormaThemeAccess.update(resolved: ocean)
        let oceanAccent = FormaTokens.Color.accent

        FormaThemeAccess.update(resolved: blossom)
        let blossomAccent = FormaTokens.Color.accent

        XCTAssertGreaterThan(ThemeTestSupport.colorDistance(oceanAccent, blossomAccent), 0.08)
    }

    func testCase07_DiscardConfirmationRendersForOceanBlueAndBlossomPinkThemes() {
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

    func testCase08_DiscardConfirmationGrowsSafelyAtLargeAccessibilityText() {
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

    func testCase08_DiscardConfirmationRendersOnSmallPhoneAtAccessibilityTextSize() {
        DiscardChangesConfirmationRenderTestSupport.assertRenders(
            size: CGSize(width: smallPhoneSize.width, height: 1_000),
            dynamicTypeSize: .accessibility3
        )
    }

    // MARK: - Wiring & accessibility

    func testPlanEditWizardUsesSharedDiscardConfirmationStateAndView() throws {
        let wizardSource = try planEditWizardSource()
        let modalSource = try discardConfirmationViewSource()

        XCTAssertTrue(wizardSource.contains("discardConfirmationState"))
        XCTAssertTrue(wizardSource.contains("DiscardChangesConfirmationView("))
        XCTAssertTrue(wizardSource.contains("PlanEditDiscardConfirmationState"))
        XCTAssertTrue(modalSource.contains(".accessibilityAddTraits(.isModal)"))
        XCTAssertTrue(modalSource.contains("Button(role: .destructive"))
    }

    // MARK: - Helpers

    private func hasUnsavedChanges(formState: PlanFormState) -> Bool {
        PlanEditWizardStepGate.hasUnsavedChanges(
            baseline: baseline,
            formState: formState
        )
    }

    private func profileSnapshot(from formState: PlanFormState) -> UserProfile {
        let age = (try? formState.resolvedAge()) ?? baseline.age
        return UserProfile(
            id: baseline.id,
            name: baseline.name,
            birthDate: formState.birthDate,
            age: age,
            sex: formState.sex,
            heightCm: Double(formState.heightCmText) ?? baseline.heightCm,
            currentWeightKg: Double(formState.currentWeightKgText) ?? baseline.currentWeightKg,
            goalWeightKg: Double(formState.goalWeightKgText) ?? baseline.goalWeightKg,
            estimatedBodyFatPercentage: Double(formState.estimatedBodyFatPercentageText),
            activityLevel: formState.activityLevel,
            trainingFrequencyPerWeek: Int(formState.trainingFrequencyPerWeekText) ?? baseline.trainingFrequencyPerWeek,
            averageSteps: Int(formState.averageStepsText) ?? baseline.averageSteps,
            dietPreference: formState.dietPreference.isEmpty ? nil : formState.dietPreference,
            unitSystem: formState.unitSystem,
            targets: baseline.targets,
            createdAt: baseline.createdAt,
            updatedAt: baseline.updatedAt
        )
    }

    private func seedProfile() async throws {
        let formState = PlanFormState(profile: baseline)
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
        try source(relativePath: "Fitness Coach/Features/Plan/UI/PlanEditWizard.swift")
    }

    private func discardConfirmationViewSource() throws -> String {
        try source(relativePath: "Fitness Coach/DesignSystem/Components/DiscardChangesConfirmationView.swift")
    }

    private func source(relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
