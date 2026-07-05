//
//  AuthGateCoordinator+PublicEntryDelegate.swift
//  Fitness Coach
//
//  Public-entry intent forwarding and delegate bridge for PublicEntryFlowCoordinator.
//

import Foundation

extension AuthGateCoordinator: PublicEntryFlowCoordinatorDelegate {

    func clearOnboardingDraft() {
        container.onboardingDraftStore.clearDraft()
    }

    func resolveLocalProfile() {
        rootModel.resolveLocalProfile()
    }

    func startPreAuthOnboardingModel() {
        onboardingShellCoordinator.ensurePreAuthOnboardingModel()
    }

    func bootstrapOnboardingModel() {
        onboardingShellCoordinator.ensureOnboardingModel()
    }

    func continueFromMissingCloudProfile() {
        rootModel.continueFromMissingCloudProfile()
    }

    func resetRootForSignedOutSession() {
        rootModel.resetForSignedOutSession()
    }

    func clearTransientAuthState() {
        authManager.clearTransientAuthState()
    }
}

extension AuthGateCoordinator {

    // MARK: - Public entry actions

    func beginOnboardingFromWelcome() {
        publicEntryFlowCoordinator.beginOnboardingFromWelcome()
    }

    func beginExistingUserSignInFromWelcome() {
        publicEntryFlowCoordinator.beginExistingUserSignInFromWelcome()
    }

    func returnToWelcomeFromExistingUserSignIn() {
        publicEntryFlowCoordinator.returnToWelcomeFromExistingUserSignIn()
    }

    func returnToWelcomeFromOnboarding() {
        publicEntryFlowCoordinator.returnToWelcomeFromOnboarding()
    }

    func beginOnboardingFromExistingUserSignIn() {
        publicEntryFlowCoordinator.beginOnboardingFromExistingUserSignIn()
    }

    func startPreAuthOnboarding() {
        publicEntryFlowCoordinator.startPreAuthOnboarding()
    }

    func signInAsExistingUser() {
        publicEntryFlowCoordinator.signInAsExistingUser()
    }

    func beginOnboardingAfterNoExistingPlan() {
        publicEntryFlowCoordinator.beginOnboardingAfterNoExistingPlan()
    }

    func useAnotherAccountAfterNoExistingPlan() {
        publicEntryFlowCoordinator.useAnotherAccountAfterNoExistingPlan()
    }

    func applyExistingUserGoogleSignInOutcome(_ outcome: GoogleSignInAttemptOutcome) {
        publicEntryFlowCoordinator.applyExistingUserGoogleSignInOutcome(outcome)
    }

    // MARK: - Public entry analytics

    func logAppShellRouteDecision(selectedRoute: AppShellRoute) {
        publicEntryFlowCoordinator.logAppShellRouteDecision(
            selectedRoute: selectedRoute,
            routeInputs: routeInputs
        )
    }

    func publicEntryAnalyticsProperties(
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil,
        reason: String? = nil
    ) -> PublicEntryAnalyticsProperties {
        publicEntryFlowCoordinator.publicEntryAnalyticsProperties(
            profileResolutionResult: profileResolutionResult,
            reason: reason
        )
    }

    func logWelcomeScreenAnalytics() {
        publicEntryFlowCoordinator.logWelcomeScreenAnalytics()
    }

    func logPublicEntry(
        _ event: PublicEntryAnalyticsEvent,
        properties: PublicEntryAnalyticsProperties
    ) {
        publicEntryFlowCoordinator.logPublicEntry(event, properties: properties)
    }

    // MARK: - Existing user sign-in analytics

    func logExistingUserSignIn(
        _ event: PublicEntryAnalyticsEvent,
        reason: ExistingUserSignInFailureKind? = nil,
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil
    ) {
        publicEntryFlowCoordinator.logExistingUserSignIn(
            event,
            reason: reason,
            profileResolutionResult: profileResolutionResult
        )
    }

    func completeExistingUserSignInSuccessIfNeeded() {
        publicEntryFlowCoordinator.completeExistingUserSignInSuccessIfNeeded()
    }

    func completeExistingUserSignInNoProfileIfNeeded() {
        publicEntryFlowCoordinator.completeExistingUserSignInNoProfileIfNeeded()
    }

    func completeExistingUserSignInFailure(_ kind: ExistingUserSignInFailureKind) {
        publicEntryFlowCoordinator.completeExistingUserSignInFailure(kind)
    }
}
