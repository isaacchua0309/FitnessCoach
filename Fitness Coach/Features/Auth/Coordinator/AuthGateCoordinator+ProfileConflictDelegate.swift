//
//  AuthGateCoordinator+ProfileConflictDelegate.swift
//  Fitness Coach
//
//  Profile conflict intent forwarding and delegate bridge for AuthProfileConflictCoordinator.
//

import Foundation

extension AuthGateCoordinator: AuthProfileConflictCoordinatorDelegate {

    func performUserInitiatedSignOut(source: String) {
        container.publicEntrySessionStore.markUserInitiatedLogout()
        prepareAuthenticatedSignOut(source: source)
        authManager.signOut()
    }
}

extension AuthGateCoordinator {

    // MARK: - Profile conflict actions

    func restoreGoogleAccountPlanAfterMismatch() {
        profileConflictCoordinator.restoreGoogleAccountPlanAfterMismatch()
    }

    func beginUseDeviceProfileAfterMismatch() {
        profileConflictCoordinator.beginUseDeviceProfileAfterMismatch()
    }

    func confirmUseDeviceProfileAfterPrompt() {
        profileConflictCoordinator.confirmUseDeviceProfileAfterPrompt()
    }

    func signOutFromAccountMismatch() {
        profileConflictCoordinator.signOutFromAccountMismatch()
    }

    func retryAccountMismatchOrOnboardingCloudCheck() {
        profileConflictCoordinator.retryAccountMismatchOrOnboardingCloudCheck()
    }

    func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext) {
        profileConflictCoordinator.presentCloudProfileUploadFailure(context: context)
    }

    func clearProfileConflictState() {
        profileConflictCoordinator.clearProfileConflictState()
    }

    func restoreExistingPlanAfterConflict() {
        profileConflictCoordinator.restoreExistingPlanAfterConflict()
    }

    func beginUseDevicePlanAfterConflict() {
        profileConflictCoordinator.beginUseDevicePlanAfterConflict()
    }

    func confirmUseDevicePlanAfterConflict() {
        profileConflictCoordinator.confirmUseDevicePlanAfterConflict()
    }

    func finishProfileConflictAfterRestore() {
        profileConflictCoordinator.finishProfileConflictAfterRestore()
    }

    func finishProfileConflictAfterUpload() {
        profileConflictCoordinator.finishProfileConflictAfterUpload()
    }

    func retryCloudProfileUpload() {
        profileConflictCoordinator.retryCloudProfileUpload()
    }

    func finishAfterSuccessfulCloudUpload(context: CloudProfileUploadFailureContext) {
        profileConflictCoordinator.finishAfterSuccessfulCloudUpload(context: context)
    }

    func continueAfterCloudUploadFailure() {
        profileConflictCoordinator.continueAfterCloudUploadFailure()
    }

    func presentProfileConflictAfterLookup(uid: String) {
        profileConflictCoordinator.presentProfileConflictAfterLookup(uid: uid)
    }
}
