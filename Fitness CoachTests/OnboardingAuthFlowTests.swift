//
//  OnboardingAuthFlowTests.swift
//  Fitness CoachTests
//
//  Forma — Auth/onboarding entry flow copy and post-auth save-plan policy.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAuthFlowCopyTests: XCTestCase {

    func testNoExistingPlanHandoffCopy() {
        let copy = FormaProductCopy.PublicEntry.NoExistingPlan.self
        XCTAssertEqual(copy.title, "We couldn't find a Forma plan for this account")
        XCTAssertEqual(
            copy.subtitle,
            "This account doesn't have a saved plan yet. Let's build one now."
        )
        XCTAssertEqual(copy.startOnboardingCTA, "Start Onboarding")
        XCTAssertEqual(copy.useAnotherAccountCTA, "Use another account")
    }

    func testBootstrapFetchFailureCopy() {
        let copy = FormaProductCopy.Onboarding.V2.BootstrapError.self
        XCTAssertEqual(copy.title, "Couldn't check your saved plan")
        XCTAssertEqual(copy.body, "Check your connection and try again.")
        XCTAssertEqual(copy.retryCTA, "Try again")
    }
}

@MainActor
final class OnboardingAuthFlowModelTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingAuthFlowModelTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testPostAuthSavePlanUsesEditingViewState() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try makePostAuthModel(container: container)

        try await advancePostAuthModelToSavePlan(model)
        XCTAssertEqual(model.currentStep, OnboardingStep.savePlan)
        XCTAssertEqual(model.viewState, OnboardingViewState.editing)
    }

    func testPostAuthSavePlanCompletionInvokesHandlerWithoutSignInIntent() async throws {
        var completionCount = 0
        let container = try AppContainer(inMemory: true)
        let model = try makePostAuthModel(container: container) {
            completionCount += 1
        }

        try await advancePostAuthModelToSavePlan(model)
        model.goNext()

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(model.pendingCompletionIntent, OnboardingCompletionIntent.signIn)
    }

    private func makePostAuthModel(
        container: AppContainer,
        onCompletion: @escaping () -> Void = {}
    ) throws -> OnboardingModel {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: onCompletion,
            draftStore: draftStore,
            analyticsEntry: .postAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }

    private func fillValidPostAuthForm(_ model: OnboardingModel) {
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
    }

    private func advancePostAuthModelToSavePlan(_ model: OnboardingModel) async throws {
        fillValidPostAuthForm(model)
        XCTAssertEqual(model.currentStep, .heightWeight)
        await OnboardingModelTestSupport.advanceTo(.review, model: model, seedForm: false)
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        model.goNext()
        model.prepareForSavePlan()
    }
}

final class OnboardingExistingAccountRoutingPolicyTests: XCTestCase {

    func testExistingUserSignInWinsOverActiveOnboardingSession() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .existingUserSignIn,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .existingUserSignIn
        )
    }

    func testSignedInMissingCloudProfileRoutesToNoExistingProfileFoundNotOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .missingCloudProfile,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
    }

    func testBootstrapFetchFailureMapsToProfileErrorNotMissingCloudInterstitial() {
        let bootstrapBody = FormaProductCopy.Onboarding.V2.BootstrapError.body
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .error(bootstrapBody)
            ),
            .profileError(bootstrapBody)
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .error(bootstrapBody)
            ),
            .noExistingProfileFound
        )
    }

    func testSignedInEntryStartsAtHeightWeight() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .postAuth), .heightWeight)
    }

    func testSignedOutEntryStartsAtIntroProof() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .preAuth), .introProof)
    }
}
