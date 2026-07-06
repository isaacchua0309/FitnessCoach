//
//  AuthGateCoordinator+PublicEntryFlowDelegate.swift
//  Fitness Coach
//
//  Delegate bridge for public-entry flow coordinator state mutations.
//

import Foundation

extension AuthGateCoordinator: PublicEntryFlowCoordinatorDelegate {

    func clearOnboardingModel() {
        onboardingModel = nil
    }

    func clearOnboardingDraft() {
        container.onboardingDraftStore.clearDraft()
    }

    func resolveLocalProfile() {
        rootModel.resolveLocalProfile()
    }

    func startPreAuthOnboardingModel() {
        ensurePreAuthOnboardingModel()
    }

    func bootstrapOnboardingModel() {
        ensureOnboardingModel()
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
