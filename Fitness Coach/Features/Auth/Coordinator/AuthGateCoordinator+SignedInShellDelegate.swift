//
//  AuthGateCoordinator+SignedInShellDelegate.swift
//  Fitness Coach
//
//  Delegate bridge for signed-in shell coordinator state mutations.
//

import Foundation

extension AuthGateCoordinator: AuthSignedInShellCoordinatorDelegate {

    func clearTestingSignedInUID() {
        #if DEBUG
        testingSignedInUID = nil
        #endif
    }

    func resetPublicEntryDestinationOnSignIn() {
        publicEntryFlowCoordinator.resetPublicEntryDestinationOnSignIn()
    }

    func handleExistingUserSignInAttemptIfNeeded(from previous: AuthState, to state: AuthState) {
        publicEntryFlowCoordinator.handleExistingUserSignInAttemptIfNeeded(from: previous, to: state)
    }

    func handleOnboardingSignInAttemptFailedIfNeeded(from previous: AuthState, to state: AuthState) {
        onboardingShellCoordinator.handleOnboardingSignInAttemptFailedIfNeeded(from: previous, to: state)
    }

    func resetPublicEntryFlagsForAccountDeletion() {
        publicEntryFlowCoordinator.resetPublicEntryFlagsForAccountDeletion()
    }

    func applyPublicEntryDestinationAfterSignOut() {
        publicEntryFlowCoordinator.applyPublicEntryDestinationAfterSignOut()
    }

    func applyWasSignedInPublicEntryReset() {
        publicEntryFlowCoordinator.applyWasSignedInPublicEntryReset()
    }

    func applyColdLaunchPublicEntryDestinationIfNeeded() -> Bool {
        publicEntryFlowCoordinator.applyColdLaunchPublicEntryDestinationIfNeeded()
    }

    func applyExplicitSignOutWelcomeIfNeeded() {
        publicEntryFlowCoordinator.applyExplicitSignOutWelcomeIfNeeded()
    }

    func resetOnboardingForSignedOutTransition() {
        onboardingShellCoordinator.resetOnboardingForSignedOutTransition()
    }

    func resetOnboardingForAuthenticatedSignOut() {
        onboardingShellCoordinator.resetOnboardingForAuthenticatedSignOut()
    }

    func clearOnboardingModelIfPolicyRequires(wasSignedIn: Bool) {
        onboardingShellCoordinator.clearOnboardingModelIfPolicyRequires(wasSignedIn: wasSignedIn)
    }

    func clearOnboardingModel() {
        onboardingShellCoordinator.clearOnboardingModel()
    }

    func clearExistingUserSessionForMissingCloudProfile() {
        publicEntryFlowCoordinator.clearExistingUserSessionForMissingCloudProfile()
    }

    func resolveOnboardingCompletionAfterSignIn(uid: String) async {
        await onboardingShellCoordinator.resolveOnboardingCompletionAfterSignIn(uid: uid)
    }

    func finishOnboardingCompletionAfterSuccessfulSync() {
        onboardingShellCoordinator.finishOnboardingCompletionAfterSuccessfulSync()
    }

    func commitLocalProfileForSavePlan() {
        onboardingShellCoordinator.commitLocalProfileForSavePlan()
    }

    func finalizeAfterRestoredExistingPlanAndClearCompletionState() {
        onboardingShellCoordinator.finalizeAfterRestoredExistingPlanAndClearCompletionState()
    }

    func finalizeAfterSuccessfulSignInAndClearCompletionState() {
        onboardingShellCoordinator.finalizeAfterSuccessfulSignInAndClearCompletionState()
    }

    func retryOnboardingCompletionCloudCheck() {
        onboardingShellCoordinator.retryOnboardingCompletionCloudCheck()
    }
}
