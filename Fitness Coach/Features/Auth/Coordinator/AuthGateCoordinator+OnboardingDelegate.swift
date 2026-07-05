//
//  AuthGateCoordinator+OnboardingDelegate.swift
//  Fitness Coach
//
//  Delegate bridge for onboarding shell coordinator state mutations.
//

import Foundation

extension AuthGateCoordinator: AuthOnboardingShellCoordinatorDelegate {

    func notifyObjectWillChange() {
        objectWillChange.send()
    }

    func isSignedIn() -> Bool {
        AppRouteResolver.isSignedIn(authManager.authState)
    }

    func currentUID() -> String? {
        authManager.currentUID
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
