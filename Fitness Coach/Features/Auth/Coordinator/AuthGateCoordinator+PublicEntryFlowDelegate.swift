//
//  AuthGateCoordinator+PublicEntryFlowDelegate.swift
//  Fitness Coach
//
//  Delegate bridge for public-entry flow coordinator state mutations.
//

import Foundation

extension AuthGateCoordinator: PublicEntryFlowCoordinatorDelegate {

    func clearOnboardingModel() {
        onboardingShellCoordinator.clearOnboardingModel()
    }

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

    func signOutFromAuthManager() {
        authManager.signOut()
    }

    func clearTransientAuthState() {
        authManager.clearTransientAuthState()
    }

    func resetRootForSignedOutSession() {
        rootModel.resetForSignedOutSession()
    }
}
