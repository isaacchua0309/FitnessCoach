//
//  AuthGateCoordinator+OnboardingDelegate.swift
//  Fitness Coach
//
//  Onboarding intent forwarding and delegate bridge for AuthOnboardingShellCoordinator.
//

import Foundation

extension AuthGateCoordinator: AuthOnboardingShellCoordinatorDelegate {

    func notifyObjectWillChange() {
        objectWillChange.send()
    }

    func isSignedIn() -> Bool {
        AppRouteResolver.isSignedIn(authManager.authState)
    }

    func rootState() -> RootViewState {
        rootModel.state
    }

    func prepareSignedInAccountNamespace(uid: String) async {
        await container.prepareSignedInAccountNamespace(uid: uid)
    }

    func beginOnboardingCompletionCloudCheck() {
        rootModel.beginOnboardingCompletionCloudCheck()
    }

    func resolveOnboardingCompletion(uid: String) async -> OnboardingCompletionOutcome {
        await container.profileBootstrapCoordinatorService.resolveOnboardingCompletion(uid: uid)
    }

    func presentProfilePlanConflict() {
        profileConflictCoordinator.presentOnboardingCompletionProfileConflict()
    }

    func presentOnboardingCloudCheckFailed() {
        rootModel.presentOnboardingCloudCheckFailed()
    }

    func suppressAutomaticPublicEntryResume() -> Bool {
        container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
    }

    func hasLocalProfile() -> Bool {
        container.profileBootstrapService.hasLocalProfile()
    }

    func localProfileAwaitingSignIn() -> Bool {
        container.profileBootstrapService.localProfileAwaitingSignIn()
    }

    func hasPersistedOnboardingDraft() -> Bool {
        container.onboardingDraftStore.hasDraft
    }
}

extension AuthGateCoordinator {

    // MARK: - Pre-auth onboarding

    func preparePreAuthOnboardingIfNeeded() {
        onboardingShellCoordinator.preparePreAuthOnboardingIfNeeded()
    }

    // MARK: - Onboarding model lifecycle

    /// Ensures the onboarding model exists whenever routing targets an initializing onboarding shell.
    func bootstrapOnboardingIfNeeded() {
        onboardingShellCoordinator.bootstrapOnboardingIfNeeded()
    }

    func ensurePreAuthOnboardingModel() {
        onboardingShellCoordinator.ensurePreAuthOnboardingModel()
    }

    func ensureOnboardingModel() {
        onboardingShellCoordinator.ensureOnboardingModel()
    }

    func handleOnboardingCompletionRequest() {
        onboardingShellCoordinator.handleOnboardingCompletionRequest()
    }

    func applyOnboardingGoogleSignInOutcome(_ outcome: GoogleSignInAttemptOutcome) {
        onboardingShellCoordinator.applyOnboardingGoogleSignInOutcome(outcome)
    }

    /// Signed-in onboarding completion: probe cloud, then sync or show conflict UI.
    func resolveOnboardingCompletionAfterSignIn(uid: String) async {
        await onboardingShellCoordinator.resolveOnboardingCompletionAfterSignIn(uid: uid)
    }

    func finishOnboardingCompletionAfterSuccessfulSync() {
        onboardingShellCoordinator.finishOnboardingCompletionAfterSuccessfulSync()
    }

    func clearOnboardingCompletionState() {
        onboardingShellCoordinator.clearOnboardingCompletionState()
    }

    func retryOnboardingCompletionCloudCheck() {
        onboardingShellCoordinator.retryOnboardingCompletionCloudCheck()
    }

    func finishOnboardingLocally() {
        onboardingShellCoordinator.finishOnboardingLocally()
    }
}
