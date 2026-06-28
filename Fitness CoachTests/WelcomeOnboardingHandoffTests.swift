//
//  WelcomeOnboardingHandoffTests.swift
//  Fitness CoachTests
//
//  Forma — Public welcome → pre-auth onboarding handoff tests.
//

import XCTest
@testable import Fitness_Coach

final class WelcomeOnboardingHandoffPolicyTests: XCTestCase {

    func testWelcomeCreatePlanUsesOnboardingStartDestination() {
        XCTAssertEqual(
            WelcomeOnboardingHandoffPolicy.createPlanDestination,
            .onboardingStart
        )
        XCTAssertEqual(
            WelcomeOnboardingHandoffPolicy.shellRoute(isOnboardingModelReady: true),
            .onboardingStart
        )
        XCTAssertEqual(
            WelcomeOnboardingHandoffPolicy.shellRoute(isOnboardingModelReady: false),
            .onboardingStartInitializing
        )
    }

    func testWelcomeCreatePlanStartsAtIntroProofNotLegacyWelcome() {
        XCTAssertEqual(WelcomeOnboardingHandoffPolicy.preAuthEntry, .preAuth)
        XCTAssertEqual(WelcomeOnboardingHandoffPolicy.canonicalFirstStep, .introProof)
        XCTAssertEqual(
            OnboardingEntry.initialStep(for: WelcomeOnboardingHandoffPolicy.preAuthEntry),
            .introProof
        )
        XCTAssertNotEqual(WelcomeOnboardingHandoffPolicy.canonicalFirstStep, .savePlan)
    }

    func testPreAuthWelcomeHandoffDoesNotRequireSignInBeforeOnboarding() {
        XCTAssertFalse(WelcomeOnboardingHandoffPolicy.requiresSignInBeforeOnboarding)
        XCTAssertTrue(WelcomeOnboardingHandoffPolicy.requiresGoogleSignInAtSavePlan)
    }

    func testPersistedDraftBypassesWelcomeOnColdLaunch() {
        let input = PublicEntryRouteResolver.Input(
            destination: .welcome,
            isOnboardingModelReady: true,
            localProfileAwaitingSignIn: false,
            hasPersistedOnboardingDraft: true,
            hasLocalProfile: false,
            pendingOnboardingCompletion: false,
            signedOutWithProfilePolicy: .requireSignIn
        )

        XCTAssertTrue(WelcomeOnboardingHandoffPolicy.shouldBypassWelcome(input))
        XCTAssertEqual(
            PublicEntryRouteResolver.resolveSignedOutShell(input),
            .onboardingStart
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true
            ),
            .onboardingStart
        )
    }

    func testWelcomeCreatePlanRouteDoesNotUseExistingUserSignIn() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: WelcomeOnboardingHandoffPolicy.createPlanDestination
            ),
            .onboardingStart
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: WelcomeOnboardingHandoffPolicy.createPlanDestination
            ),
            .existingUserSignIn
        )
    }
}

@MainActor
final class WelcomeOnboardingHandoffModelTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "WelcomeOnboardingHandoffModelTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testWelcomeCreatePlanStartsPreAuthOnboardingAtIntroProof() throws {
        let container = try AppContainer(inMemory: true)
        let model = container.makeOnboardingModel(
            entry: WelcomeOnboardingHandoffPolicy.preAuthEntry,
            onCompletion: {}
        )

        XCTAssertEqual(model.currentStep, .introProof)
        XCTAssertEqual(model.flowFloor, .introProof)
        XCTAssertTrue(model.requiresGoogleSignInAtSavePlan)
        XCTAssertFalse(container.profileBootstrapService.hasLocalProfile())
    }

    func testDraftResumesAtSavedStepWithoutShowingLegacyWelcome() throws {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        draftStore.saveDraft(
            OnboardingDraft(formState: formState, step: .targetWeight)
        )

        let container = try AppContainer(inMemory: true, onboardingUserDefaults: draftDefaults)
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore
        )

        XCTAssertEqual(model.currentStep, .targetWeight)
        XCTAssertNotEqual(model.currentStep, .introProof)
    }

    func testLegacyDraftWelcomeMapsToIntroProof() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.welcome.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .introProof)
    }

    func testPreAuthCompletionStillCommitsProfileAndRequestsSignIn() async throws {
        let container = try AppContainer(inMemory: true)
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: WelcomeOnboardingHandoffPolicy.preAuthEntry,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )

        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.planReveal, model: model, seedForm: false)

        model.goNext()
        XCTAssertEqual(model.currentStep, .savePlan)
        XCTAssertTrue(model.hasCommittedLocalProfile)
        XCTAssertNotNil(try container.userProfileService.getCurrentProfile())

        model.goNext()
        XCTAssertEqual(model.pendingCompletionIntent, .signIn)
    }
}
