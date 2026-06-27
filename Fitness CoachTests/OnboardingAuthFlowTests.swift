//
//  OnboardingAuthFlowTests.swift
//  Fitness CoachTests
//
//  Forma — Auth/onboarding entry flow copy and post-auth save-plan policy.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAuthFlowCopyTests: XCTestCase {

    func testLandingUsesGetStartedAndExistingAccountActions() {
        let landing = FormaProductCopy.Onboarding.V2.Landing.self
        XCTAssertEqual(landing.cta, "Get started")
        XCTAssertEqual(landing.existingAccountAction, "I already have an account")
        XCTAssertFalse(landing.existingAccountAction.localizedCaseInsensitiveContains("Google"))
    }

    func testMissingCloudProfileHandoffCopy() {
        let copy = FormaProductCopy.Onboarding.V2.MissingCloudProfile.self
        XCTAssertEqual(copy.title, "Looks like you're new")
        XCTAssertEqual(
            copy.body,
            "We couldn't find a saved Forma plan for this Google account. Let's set up your account."
        )
        XCTAssertEqual(copy.continueCTA, "Continue")
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

    func testPostAuthSavePlanUsesEditingViewState() async throws {
        let container = try AppContainer(inMemory: true)
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            analyticsEntry: .postAuth,
            flowScope: .v2PostAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        try await advancePostAuthModelToSavePlan(model)
        XCTAssertEqual(model.currentStep, OnboardingStep.savePlan)
        XCTAssertEqual(model.viewState, OnboardingViewState.editing)
    }

    func testPostAuthSavePlanCompletionInvokesHandlerWithoutSignInIntent() async throws {
        var completionCount = 0
        let container = try AppContainer(inMemory: true)
        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: { completionCount += 1 },
            analyticsEntry: .postAuth,
            flowScope: .v2PostAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        try await advancePostAuthModelToSavePlan(model)
        model.goNext()

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(model.pendingCompletionIntent, OnboardingCompletionIntent.signIn)
    }

    private func fillValidPostAuthForm(_ model: OnboardingModel) {
        model.formState.ageText = "28"
        model.formState.sex = .female
        model.formState.heightCmText = "168"
        model.formState.currentWeightKgText = "72"
        model.formState.goalWeightKgText = "65"
        model.formState.activityLevel = .moderatelyActive
        model.formState.trainingFrequencyPerWeekText = "3"
        model.formState.averageStepsText = "5000"
        model.formState.selectPaceChoice(.moderate)
    }

    private func advancePostAuthModelToSavePlan(_ model: OnboardingModel) async throws {
        fillValidPostAuthForm(model)
        XCTAssertEqual(model.currentStep, OnboardingStep.motivation)
        model.goNext() // body
        model.goNext() // goal
        model.goNext() // activity
        model.goNext() // preferences
        model.goNext() // summary
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        model.goNext() // planReveal -> savePlan prep
        model.prepareForSavePlan()
    }
}

final class OnboardingExistingAccountRoutingPolicyTests: XCTestCase {

    func testV2DoesNotPreferSignInShellWhenOnboardingSessionIsActive() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .signIn,
                isV2Enabled: true,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .localOnboarding
        )
    }

    func testSignedInMissingCloudProfileRoutesToInterstitialNotOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .missingCloudProfile
            ),
            .missingCloudProfile
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
            .missingCloudProfile
        )
    }

    func testV2PostAuthFlowScopeSkipsGoogleSignInAtSavePlan() {
        XCTAssertEqual(OnboardingFlowScope.v2PostAuth.entryStep, .motivation)
        XCTAssertNotEqual(OnboardingFlowScope.v2PostAuth, OnboardingFlowScope.v2Full)
    }

    func testV2FullFlowScopeUsesLandingEntryForPreAuth() {
        XCTAssertEqual(OnboardingFlowScope.v2Full.entryStep, .landing)
    }
}
