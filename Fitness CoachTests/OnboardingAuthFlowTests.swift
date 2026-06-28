//
//  OnboardingAuthFlowTests.swift
//  Fitness CoachTests
//
//  Forma — Auth/onboarding entry flow copy and post-auth save-plan policy.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingAuthFlowCopyTests: XCTestCase {

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
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )

        try await advancePostAuthModelToSavePlan(model)
        model.goNext()

        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(model.pendingCompletionIntent, OnboardingCompletionIntent.signIn)
    }

    private func fillValidPostAuthForm(_ model: OnboardingModel) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &model.formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &model.formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &model.formState)
        model.formState.sex = .female
        model.formState.activityLevel = .moderatelyActive
        OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &model.formState)
        model.formState.selectPaceChoice(.moderate)
    }

    private func advancePostAuthModelToSavePlan(_ model: OnboardingModel) async throws {
        fillValidPostAuthForm(model)
        XCTAssertEqual(model.currentStep, .heightWeight)
        while model.currentStep != .review {
            model.goNext()
        }
        model.beginGeneration()
        await model.flushPendingGenerationForTesting()
        model.goNext()
        model.prepareForSavePlan()
    }
}

final class OnboardingExistingAccountRoutingPolicyTests: XCTestCase {

    func testExistingAccountRoutingPolicyPrefersActiveOnboardingSession() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .signIn,
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

    func testSignedInEntryStartsAtHeightWeight() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .postAuth), .heightWeight)
    }

    func testSignedOutEntryStartsAtIntroProof() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .preAuth), .introProof)
    }
}
