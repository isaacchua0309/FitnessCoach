//
//  OnboardingModelTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding v2 navigation, generation, and draft persistence tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingModelTests: XCTestCase {

    private var v2FlagPrevious = false
    private var routingModePrevious: String?
    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() async throws {
        try await super.setUp()
        v2FlagPrevious = UserDefaults.standard.bool(forKey: OnboardingStepPolicy.featureFlagKey)
        routingModePrevious = UserDefaults.standard.string(forKey: OnboardingV2FeatureFlag.routingModeKey)
        UserDefaults.standard.set(true, forKey: OnboardingStepPolicy.featureFlagKey)
        UserDefaults.standard.set(
            OnboardingV2RoutingMode.preAuth.rawValue,
            forKey: OnboardingV2FeatureFlag.routingModeKey
        )

        draftSuiteName = "OnboardingModelTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
        draftStore.clearDraft()
    }

    override func tearDown() async throws {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        UserDefaults.standard.set(v2FlagPrevious, forKey: OnboardingStepPolicy.featureFlagKey)
        if let routingModePrevious {
            UserDefaults.standard.set(routingModePrevious, forKey: OnboardingV2FeatureFlag.routingModeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV2FeatureFlag.routingModeKey)
        }
        try await super.tearDown()
    }

    // MARK: - Step graph

    func testV2StepGraphAdvancesThroughSummaryWithValidForm() throws {
        let model = try makeModel()
        fillValidForm(model)

        XCTAssertEqual(model.currentStep, .landing)

        model.goNext()
        XCTAssertEqual(model.currentStep, .welcome)

        model.goNext()
        XCTAssertEqual(model.currentStep, .motivation)

        model.goNext()
        XCTAssertEqual(model.currentStep, .body)

        model.goNext()
        XCTAssertEqual(model.currentStep, .goal)

        model.goNext()
        XCTAssertEqual(model.currentStep, .activity)

        model.goNext()
        XCTAssertEqual(model.currentStep, .preferences)

        model.goNext()
        XCTAssertEqual(model.currentStep, .summary)
    }

    func testMotivationOptionalDoesNotBlockProgress() throws {
        let model = try makeModel()
        navigateToMotivation(model)

        XCTAssertTrue(model.formState.selectedMotivations.isEmpty)
        model.goNext()
        XCTAssertEqual(model.currentStep, .body)
    }

    func testPreferencesOptionalDoesNotBlockProgress() throws {
        let model = try makeModel()
        navigateToPreferences(model)

        XCTAssertTrue(model.formState.loggingPreferences.isEmpty)
        model.goNext()
        XCTAssertEqual(model.currentStep, .summary)
    }

    // MARK: - Validation gates

    func testInvalidBodyBlocksProgress() throws {
        let model = try makeModel()
        navigateToBody(model)

        model.goNext()
        XCTAssertEqual(model.currentStep, .body)
        XCTAssertNotNil(model.errorMessage)
    }

    func testInvalidGoalBlocksProgress() throws {
        let model = try makeModel()
        navigateToGoal(model)
        model.formState.goalWeightKgText = ""

        model.goNext()
        XCTAssertEqual(model.currentStep, .goal)
        XCTAssertNotNil(model.errorMessage)
    }

    func testInvalidActivityBlocksProgress() throws {
        let model = try makeModel()
        navigateToActivity(model)
        model.formState.averageStepsText = ""

        model.goNext()
        XCTAssertEqual(model.currentStep, .activity)
        XCTAssertNotNil(model.errorMessage)
    }

    // MARK: - Generation

    func testGeneratingRequiresValidRequiredFields() async throws {
        let model = try makeModel()
        navigateToSummary(model)
        model.formState.ageText = ""

        model.beginGeneration()
        await model.flushPendingGenerationForTesting()

        XCTAssertEqual(model.currentStep, .body)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.generatedPlan)
    }

    func testBeginGenerationBuildsPlanAndRevealState() async throws {
        let model = try makeModel()
        navigateToSummary(model)

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

        XCTAssertEqual(model.currentStep, .summary)
        XCTAssertNil(model.generatedPlan)
        XCTAssertNil(model.planRevealState)
    }

    func testGeneratingPlanStepDisallowsBack() async throws {
        let model = try makeModel()
        navigateToSummary(model)

        model.beginGeneration()
        XCTAssertEqual(model.currentStep, .generatingPlan)
        model.goBack()
        XCTAssertEqual(model.currentStep, .generatingPlan)

        await model.flushPendingGenerationForTesting()
    }

    // MARK: - Save flow

    func testPreAuthFlowRequiresGoogleSignInAtSavePlan() throws {
        let model = try makeModel()
        XCTAssertTrue(model.requiresGoogleSignInAtSavePlan)
    }

    func testPostAuthFlowSkipsGoogleSignInAtSavePlan() throws {
        let container = try AppContainer(inMemory: true)
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: .postAuth,
            flowScope: .v2PostAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
        XCTAssertFalse(model.requiresGoogleSignInAtSavePlan)
    }

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

    func testSignInFailureRestoresAwaitingSignInWithoutClearingLocalProfile() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try makeModel(container: container)
        try await advanceToPlanReveal(model)
        model.goNext()

        model.beginSignInForCompletion()
        model.handleSignInCompletionFailure(
            message: FormaProductCopy.Onboarding.V2.SavePlan.signInRetryMessage
        )

        XCTAssertEqual(model.viewState, .awaitingSignIn)
        XCTAssertEqual(model.errorMessage, FormaProductCopy.Onboarding.V2.SavePlan.signInRetryMessage)
        XCTAssertNil(draftStore.loadDraft())
        XCTAssertNotNil(model.generatedPlan)
        XCTAssertNotNil(model.formState.ageText)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())
    }

    func testCompleteWithoutAccountClearsDraftWhenAllowed() async throws {
        let container = try AppContainer(
            inMemory: true,
            onboardingUserDefaults: draftDefaults,
            onboardingRoutingConfiguration: OnboardingRoutingConfiguration(
                isV2Enabled: true,
                signedOutWithProfilePolicy: .allowLocalMain
            )
        )
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            allowsLocalOnlyContinuation: true
        )
        fillValidForm(model)
        navigateToSummary(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        model.goNext()

        model.completeWithoutAccount()

        XCTAssertEqual(model.pendingCompletionIntent, .localOnly)
        XCTAssertNil(draftStore.loadDraft())
        XCTAssertTrue(model.hasLocalProfile)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())
    }

    func testCompleteWithoutAccountIgnoredWhenPolicyRequiresSignIn() async throws {
        let model = try makeModel()
        try await advanceToPlanReveal(model)
        model.goNext()

        model.completeWithoutAccount()

        XCTAssertNil(model.pendingCompletionIntent)
        XCTAssertNil(draftStore.loadDraft())
    }

    // MARK: - Draft autosave

    func testDraftAutosavesOnMeaningfulStepChange() throws {
        let model = try makeModel()
        fillValidForm(model)
        model.formState.name = "Alex"

        model.goNext()

        let draft = try XCTUnwrap(draftStore.loadDraft())
        XCTAssertEqual(draft.currentStep, .welcome)
        XCTAssertEqual(draft.makeFormState().name, "Alex")
    }

    func testFlushDraftSnapshotPersistsCurrentStepWithoutNavigation() throws {
        let model = try makeModel()
        fillValidForm(model)
        model.formState.name = "Mid-step"

        model.flushDraftSnapshotIfNeeded()

        let draft = try XCTUnwrap(draftStore.loadDraft())
        XCTAssertEqual(draft.currentStep, .landing)
        XCTAssertEqual(draft.makeFormState().name, "Mid-step")
    }

    func testRestoresDraftOnInitialization() throws {
        var formState = OnboardingFormState()
        formState.name = "Restored"
        formState.ageText = "30"
        formState.heightCmText = "170"
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "75"
        formState.selectPaceChoice(.moderate)

        draftStore.saveDraft(
            OnboardingDraft(
                formState: formState,
                currentStep: .goal
            )
        )

        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .goal)
        XCTAssertEqual(model.formState.name, "Restored")
    }

    func testRestoresGeneratingPlanDraftToSummary() throws {
        draftStore.saveDraft(
            OnboardingDraft(
                formState: OnboardingFormState(),
                currentStep: .generatingPlan
            )
        )

        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .summary)
    }

    // MARK: - Helpers

    private func makeModel(container: AppContainer? = nil) throws -> OnboardingModel {
        let container = try container ?? AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            flowScope: .v2Full,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            allowsLocalOnlyContinuation: container.onboardingRoutingConfiguration.allowsLocalOnlyContinuation
        )
    }

    private func fillValidForm(_ model: OnboardingModel) {
        model.formState = validFormState()
    }

    private func validFormState() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"
        state.selectPaceChoice(.moderate)
        return state
    }

    private func navigateToMotivation(_ model: OnboardingModel) {
        model.goNext()
        model.goNext()
    }

    private func navigateToBody(_ model: OnboardingModel) {
        navigateToMotivation(model)
        model.goNext()
    }

    private func navigateToGoal(_ model: OnboardingModel) {
        fillValidForm(model)
        navigateToBody(model)
        model.goNext()
    }

    private func navigateToActivity(_ model: OnboardingModel) {
        navigateToGoal(model)
        model.goNext()
    }

    private func navigateToPreferences(_ model: OnboardingModel) {
        navigateToActivity(model)
        model.goNext()
    }

    private func navigateToSummary(_ model: OnboardingModel) {
        navigateToPreferences(model)
        model.goNext()
    }

    private func advanceToPlanReveal(_ model: OnboardingModel) async throws {
        navigateToSummary(model)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        XCTAssertEqual(model.currentStep, .planReveal)
    }
}
