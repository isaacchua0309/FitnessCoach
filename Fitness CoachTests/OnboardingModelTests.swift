//
//  OnboardingModelTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical onboarding navigation, generation, and draft persistence tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingModelTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingModelTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    // MARK: - Entry

    func testPreAuthEntryStartsAtIntroProof() throws {
        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .introProof)
        XCTAssertTrue(model.requiresGoogleSignInAtSavePlan)
    }

    func testPostAuthEntryStartsAtHeightWeight() throws {
        let model = try makeModel(entry: .postAuth)
        XCTAssertEqual(model.currentStep, .heightWeight)
        XCTAssertFalse(model.requiresGoogleSignInAtSavePlan)
        XCTAssertFalse(model.canGoBack)
    }

    // MARK: - Generation

    func testBeginGenerationRoutesToInvalidStepWhenBirthdayMissing() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.formState.birthDate = nil
        model.formState.ageText = ""

        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertEqual(model.currentStep, .birthday)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.generatedPlan)
    }

    func testBeginGenerationBuildsPlanAndRevealState() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.beginGeneration()
        XCTAssertEqual(model.currentStep, .generatingPlan)
        XCTAssertEqual(model.viewState, .generatingPlanAnimated)

        await model.flushPendingGenerationForTesting()

        XCTAssertEqual(model.currentStep, .planReveal)
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertNotNil(model.planRevealState)
        XCTAssertNil(model.errorMessage)
    }

    func testBackFromPlanRevealClearsGeneratedPlan() async throws {
        let model = try makeModel()
        try await advanceToPlanReveal(model)

        model.goBack()

        XCTAssertEqual(model.currentStep, .review)
        XCTAssertNil(model.generatedPlan)
        XCTAssertNil(model.planRevealState)
    }

    func testGeneratingPlanStepDisallowsBack() async throws {
        let model = try makeModel()
        await navigateToReview(model)

        model.beginGeneration()
        XCTAssertEqual(model.currentStep, .generatingPlan)
        model.goBack()
        XCTAssertEqual(model.currentStep, .generatingPlan)

        await model.flushPendingGenerationForTesting()
    }

    // MARK: - Save flow

    func testPlanRevealTransitionSavesLocalProfileWithoutDeletingOnSaveBack() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try makeModel(container: container)
        try await advanceToPlanReveal(model)

        model.goNext()
        XCTAssertEqual(model.currentStep, .savePlan)
        XCTAssertTrue(model.hasLocalProfile)
        XCTAssertTrue(model.hasCommittedLocalProfile)
        XCTAssertNil(draftStore.loadDraft())
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())

        model.goBack()
        XCTAssertEqual(model.currentStep, .planReveal)
        XCTAssertTrue(model.hasLocalProfile)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())
    }

    func testPrepareForSavePlanClearsDraftAfterLocalCommit() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try makeModel(container: container)
        try await advanceToPlanReveal(model)

        model.prepareForSavePlan()

        XCTAssertTrue(model.hasCommittedLocalProfile)
        XCTAssertNil(draftStore.loadDraft())
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())
    }

    func testSignInCompletionPreservesGeneratedPlanAfterLocalCommit() async throws {
        let model = try makeModel()
        try await advanceToPlanReveal(model)

        model.goNext()
        XCTAssertEqual(model.currentStep, .savePlan)
        XCTAssertNil(draftStore.loadDraft())

        model.goNext()
        XCTAssertEqual(model.pendingCompletionIntent, .signIn)
        XCTAssertNotNil(model.generatedPlan)
    }

    // MARK: - Draft autosave

    func testDraftAutosavesOnMeaningfulStepChange() throws {
        let model = try makeModel()
        seedValidForm(&model.formState)
        model.formState.name = "Alex"

        model.goNext()

        let draft = try XCTUnwrap(draftStore.loadDraft())
        XCTAssertEqual(draft.step, .introProof)
        XCTAssertEqual(draft.makeFormState().name, "Alex")
    }

    func testRestoresDraftAtGoalToTargetWeight() throws {
        var formState = OnboardingFormState()
        formState.name = "Restored"
        seedValidForm(&formState)

        draftStore.saveDraft(
            OnboardingDraft(formState: formState, step: .targetWeight)
        )

        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .targetWeight)
        XCTAssertEqual(model.formState.name, "Restored")
    }

    func testRestoresGeneratingPlanDraftToReview() throws {
        draftStore.saveDraft(
            OnboardingDraft(formState: OnboardingFormState(), step: .generatingPlan)
        )

        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .review)
    }

    // MARK: - Helpers

    private func makeModel(
        container: AppContainer? = nil,
        entry: OnboardingAnalyticsEntry = .preAuth
    ) throws -> OnboardingModel {
        let container = try container ?? AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: entry,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func seedValidForm(_ formState: inout OnboardingFormState) {
        OnboardingModelTestSupport.seedCanonicalForm(&formState)
    }

    private func navigateToReview(_ model: OnboardingModel, preserveForm: Bool = false) async {
        if !preserveForm {
            seedValidForm(&model.formState)
        }
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)
    }

    private func advanceToPlanReveal(_ model: OnboardingModel) async throws {
        await navigateToReview(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)
    }
}
