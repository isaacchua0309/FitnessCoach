//
//  AuthGateCoordinator+SignedInDelegate.swift
//  Fitness Coach
//
//  Signed-in intent forwarding and delegate bridge for AuthSignedInShellCoordinator.
//

import Foundation

extension AuthGateCoordinator: AuthSignedInShellCoordinatorDelegate {

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

    func clearExistingUserSessionForMissingCloudProfile() {
        publicEntryFlowCoordinator.clearExistingUserSessionForMissingCloudProfile()
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
}

extension AuthGateCoordinator {

    // MARK: - Signed-in flow

    func signOutFromAccount() {
        signedInShellCoordinator.signOutFromAccount()
    }

    func wireAccountDeletionRouter() {
        signedInShellCoordinator.wireAccountDeletionRouter()
    }

    func handleAccountDeletionCompleted(scope: AccountDeletionScope) {
        signedInShellCoordinator.handleAccountDeletionCompleted(scope: scope)
    }

    func syncUnsyncedLocalProfile(uid: String) {
        signedInShellCoordinator.syncUnsyncedLocalProfile(uid: uid)
    }

    // MARK: - Auth / root reactions

    func handleAuthStateChange(from previous: AuthState, to state: AuthState) {
        signedInShellCoordinator.handleAuthStateChange(from: previous, to: state)
    }

    func prepareAuthenticatedSignOut(source: String) {
        signedInShellCoordinator.prepareAuthenticatedSignOut(source: source)
    }

    func reconcileSignedInProfile(uid: String, isFreshSignIn: Bool) {
        signedInShellCoordinator.reconcileSignedInProfile(uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func handleSignedOutTransition(
        from previous: AuthState,
        to state: AuthState,
        wasSignedIn: Bool
    ) {
        signedInShellCoordinator.handleSignedOutTransition(
            from: previous,
            to: state,
            wasSignedIn: wasSignedIn
        )
    }

    func runExistingUserSignInResolution(uid: String, isFreshSignIn: Bool) async {
        await signedInShellCoordinator.runExistingUserSignInResolution(uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func applyExistingUserSignInResolution(
        _ result: ExistingUserSignInResolutionResult,
        uid: String
    ) {
        signedInShellCoordinator.applyExistingUserSignInResolution(result, uid: uid)
    }

    func retryExistingUserProfileResolution() {
        signedInShellCoordinator.retryExistingUserProfileResolution()
    }

    func applyReconcileDecision(
        _ decision: SignedInProfileReconcileDecision,
        uid: String,
        isFreshSignIn: Bool
    ) {
        signedInShellCoordinator.applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func performOwnershipCloudLookup(uid: String, isFreshSignIn: Bool) {
        signedInShellCoordinator.performOwnershipCloudLookup(uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func handleRootStateChange(_ state: RootViewState) {
        signedInShellCoordinator.handleRootStateChange(state)
    }

    func retryProfileLoad() {
        signedInShellCoordinator.retryProfileLoad()
    }
}
