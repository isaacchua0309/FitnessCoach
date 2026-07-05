//
//  AuthProfileConflictCoordinator.swift
//  Fitness Coach
//
//  Profile plan conflict and account mismatch orchestration for the auth gate shell.
//

import Foundation

@MainActor
protocol AuthProfileConflictCoordinatorDelegate: AnyObject {
    var conflictCloudDocument: CloudUserProfileDocument? { get set }
    var profileConflictContext: ProfileConflictResolutionContext { get set }
    var isResolvingProfileConflict: Bool { get set }
    var showUseDevicePlanOverwriteConfirmation: Bool { get set }
    var isResolvingAccountMismatch: Bool { get set }
    var showUseDeviceProfileConfirmation: Bool { get set }
    var retryFromAccountMismatch: Bool { get set }
    var pendingUploadFailureContext: CloudProfileUploadFailureContext? { get set }
    var awaitingCloudSync: Bool { get set }
    var isRetryingCloudUpload: Bool { get set }
    var existingUserSignInSessionActive: Bool { get set }
    var pendingExistingUserSignIn: Bool { get set }

    func currentUID() -> String?
    func scheduleRouteToMainWithAccountRestore(uid: String, reason: AccountRestoreReason)
    func performUserInitiatedSignOut(source: String)
    func clearOnboardingModel()
    func retryOnboardingCompletionCloudCheck()
    func finishOnboardingCompletionAfterSuccessfulSync()
    func commitLocalProfileForSavePlan()
    func finalizeAfterRestoredExistingPlanAndClearCompletionState()
    func finalizeAfterSuccessfulSignInAndClearCompletionState()
    func completeExistingUserSignInSuccessIfNeeded()
    func logExistingUserSignIn(
        _ event: PublicEntryAnalyticsEvent,
        reason: ExistingUserSignInFailureKind?,
        profileResolutionResult: ExistingUserSignInResolutionResult?
    )
}

@MainActor
final class AuthProfileConflictCoordinator {

    private weak var delegate: AuthProfileConflictCoordinatorDelegate?
    private let container: AppContainer
    private let authManager: AuthManager
    private let rootModel: RootModel

    init(container: AppContainer, authManager: AuthManager, rootModel: RootModel) {
        self.container = container
        self.authManager = authManager
        self.rootModel = rootModel
    }

    func configure(delegate: AuthProfileConflictCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Account mismatch

    func restoreGoogleAccountPlanAfterMismatch() {
        guard let uid = authManager.currentUID else { return }

        delegate?.isResolvingAccountMismatch = true

        Task { @MainActor in
            let outcome = await container.profileBootstrapCoordinatorService.restoreGoogleAccountPlan(uid: uid)

            switch outcome {
            case .restoredToMain:
                try? container.actionCenter.syncTodayTargetsFromProfile()
                container.onboardingCoachingContextStore.clear()
                delegate?.isResolvingAccountMismatch = false
                delegate?.awaitingCloudSync = false
                delegate?.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .accountSwitch)
            case .missingCloudProfile:
                delegate?.isResolvingAccountMismatch = false
                delegate?.clearOnboardingModel()
                rootModel.presentMissingCloudProfile()
            case .cloudFetchFailed:
                delegate?.isResolvingAccountMismatch = false
                delegate?.retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func beginUseDeviceProfileAfterMismatch() {
        guard let uid = authManager.currentUID else { return }

        delegate?.isResolvingAccountMismatch = true

        Task { @MainActor in
            let outcome = await container.profileBootstrapCoordinatorService.prepareUseDeviceProfile(uid: uid)
            delegate?.isResolvingAccountMismatch = false

            switch outcome {
            case .cloudProfileConflict(let document):
                delegate?.conflictCloudDocument = document
                delegate?.profileConflictContext = .onboardingCompletion
                rootModel.presentProfilePlanConflict()
            case .requiresLocalLinkConfirmation:
                delegate?.showUseDeviceProfileConfirmation = true
            case .cloudFetchFailed:
                delegate?.retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func confirmUseDeviceProfileAfterPrompt() {
        guard let uid = authManager.currentUID else { return }

        delegate?.isResolvingAccountMismatch = true

        Task { @MainActor in
            do {
                _ = try container.profileBootstrapCoordinatorService.confirmLinkLocalProfileToAccount(uid: uid)
                delegate?.isResolvingAccountMismatch = false
                delegate?.awaitingCloudSync = false
                delegate?.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .accountSwitch)
            } catch {
                delegate?.isResolvingAccountMismatch = false
                delegate?.retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func signOutFromAccountMismatch() {
        delegate?.performUserInitiatedSignOut(source: "account_profile_mismatch")
    }

    func retryAccountMismatchOrOnboardingCloudCheck() {
        guard let delegate else { return }
        if delegate.retryFromAccountMismatch {
            delegate.retryFromAccountMismatch = false
            rootModel.presentAccountProfileMismatch()
            restoreGoogleAccountPlanAfterMismatch()
            return
        }
        delegate.retryOnboardingCompletionCloudCheck()
    }

    func presentAccountProfileMismatch() {
        rootModel.presentAccountProfileMismatch()
    }

    // MARK: - Profile plan conflict

    func presentOnboardingCompletionProfileConflict() {
        guard let delegate else { return }
        delegate.profileConflictContext = .onboardingCompletion
        rootModel.presentProfilePlanConflict()
    }

    func presentProfileConflictAfterLookup(uid: String) {
        Task { @MainActor in
            guard let delegate else { return }
            switch await container.profileBootstrapService.resolveCloudProfile(
                uid: uid,
                context: .ownershipResolution
            ) {
            case .found(let document):
                delegate.conflictCloudDocument = document
                delegate.profileConflictContext = .accountOrOwnershipReconcile
                rootModel.presentProfilePlanConflict()
            case .missing, .failed:
                if delegate.existingUserSignInSessionActive {
                    delegate.logExistingUserSignIn(
                        .existingSignInFailed,
                        reason: .profileLookupFailed,
                        profileResolutionResult: .lookupFailed
                    )
                    delegate.existingUserSignInSessionActive = false
                    rootModel.presentExistingUserProfileLookupFailed()
                } else {
                    rootModel.presentOnboardingCloudCheckFailed()
                }
            }
        }
    }

    func clearProfileConflictState() {
        guard let delegate else { return }
        delegate.conflictCloudDocument = nil
        delegate.isResolvingProfileConflict = false
        delegate.profileConflictContext = .accountOrOwnershipReconcile
    }

    func restoreExistingPlanAfterConflict() {
        guard let delegate,
              let cloudDocument = delegate.conflictCloudDocument,
              let uid = authManager.currentUID else { return }

        delegate.isResolvingProfileConflict = true

        Task { @MainActor in
            do {
                _ = try container.profileBootstrapCoordinatorService.restoreExistingPlanAfterConflict(
                    uid: uid,
                    cloudDocument: cloudDocument
                )
                try container.actionCenter.syncTodayTargetsFromProfile()
                container.onboardingCoachingContextStore.clear()
                finishProfileConflictAfterRestore()
            } catch {
                delegate.isResolvingProfileConflict = false
                ProfileBootstrapDebugLogger.error(
                    "Failed to restore existing cloud profile after conflict",
                    fields: ["uid": uid],
                    underlying: error
                )
                rootModel.presentOnboardingCloudCheckFailed()
            }
        }
    }

    func beginUseDevicePlanAfterConflict() {
        delegate?.showUseDevicePlanOverwriteConfirmation = true
    }

    func confirmUseDevicePlanAfterConflict() {
        guard let delegate, let uid = authManager.currentUID else { return }

        delegate.isResolvingProfileConflict = true

        Task { @MainActor in
            do {
                if delegate.profileConflictContext == .onboardingCompletion {
                    delegate.commitLocalProfileForSavePlan()
                }
                try await container.profileBootstrapCoordinatorService.uploadDevicePlanAfterConflict(uid: uid)
                delegate.isResolvingProfileConflict = false
                finishProfileConflictAfterUpload()
            } catch {
                delegate.isResolvingProfileConflict = false
                ProfileBootstrapDebugLogger.error(
                    "profile_conflict_upload_failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                presentCloudProfileUploadFailure(context: .conflictReplace)
            }
        }
    }

    func finishProfileConflictAfterRestore() {
        guard let delegate, let uid = authManager.currentUID else { return }
        switch delegate.profileConflictContext {
        case .onboardingCompletion:
            delegate.finalizeAfterRestoredExistingPlanAndClearCompletionState()
        case .accountOrOwnershipReconcile:
            clearProfileConflictState()
            clearStaleOnboardingDraftIfSafe()
            delegate.completeExistingUserSignInSuccessIfNeeded()
        }
        delegate.awaitingCloudSync = false
        delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
    }

    func finishProfileConflictAfterUpload() {
        guard let delegate, let uid = authManager.currentUID else { return }
        try? container.actionCenter.syncTodayTargetsFromProfile()
        switch delegate.profileConflictContext {
        case .onboardingCompletion:
            delegate.finalizeAfterSuccessfulSignInAndClearCompletionState()
        case .accountOrOwnershipReconcile:
            clearProfileConflictState()
            clearStaleOnboardingDraftIfSafe()
            delegate.completeExistingUserSignInSuccessIfNeeded()
        }
        delegate.awaitingCloudSync = false
        delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
    }

    // MARK: - Cloud upload failure (conflict surfaces)

    func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext) {
        guard let delegate else { return }
        delegate.pendingUploadFailureContext = context
        container.profileCloudSyncStore.clear()
        container.cloudUploadFailureNotifier.clear()
        delegate.awaitingCloudSync = false
        rootModel.presentCloudProfileUploadFailed()
    }

    func retryCloudProfileUpload() {
        guard let delegate,
              let uid = authManager.currentUID,
              let context = delegate.pendingUploadFailureContext else { return }

        delegate.isRetryingCloudUpload = true

        Task { @MainActor in
            defer { delegate.isRetryingCloudUpload = false }
            do {
                try await container.profileBootstrapCoordinatorService.retryCloudProfileUpload(
                    uid: uid,
                    context: context
                )
                let succeededContext = context
                delegate.pendingUploadFailureContext = nil
                container.cloudUploadFailureNotifier.clear()
                finishAfterSuccessfulCloudUpload(context: succeededContext)
            } catch is CloudProfileWriteError {
                container.profileCloudSyncStore.clear()
                rootModel.presentCloudProfileUploadFailed()
            } catch {
                container.profileCloudSyncStore.clear()
                ProfileBootstrapDebugLogger.error(
                    "cloud_profile_upload_retry_failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                rootModel.presentCloudProfileUploadFailed()
            }
        }
    }

    func finishAfterSuccessfulCloudUpload(context: CloudProfileUploadFailureContext) {
        guard let delegate else { return }
        switch context {
        case .onboardingCompletion:
            delegate.finishOnboardingCompletionAfterSuccessfulSync()
        case .reconcileUpload:
            delegate.awaitingCloudSync = false
            guard let uid = authManager.currentUID else { return }
            delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
        case .conflictReplace:
            finishProfileConflictAfterUpload()
        case .profileEdit:
            delegate.awaitingCloudSync = false
            guard let uid = authManager.currentUID else { return }
            delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
        }
    }

    func continueAfterCloudUploadFailure() {
        guard let delegate else { return }
        let context = delegate.pendingUploadFailureContext
        container.profileCloudSyncStore.clear()
        delegate.pendingUploadFailureContext = nil
        container.cloudUploadFailureNotifier.clear()

        switch context {
        case .onboardingCompletion:
            delegate.finalizeAfterSuccessfulSignInAndClearCompletionState()
        case .reconcileUpload, .conflictReplace:
            clearProfileConflictState()
        case .profileEdit, .none:
            break
        }

        delegate.awaitingCloudSync = false
        guard let uid = authManager.currentUID else { return }
        delegate.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
    }

    // MARK: - Reconcile / resolution hooks

    func handleExistingUserSignInConflict(uid: String) {
        guard let delegate else { return }
        delegate.awaitingCloudSync = false
        delegate.pendingExistingUserSignIn = false
        delegate.profileConflictContext = .accountOrOwnershipReconcile
        presentProfileConflictAfterLookup(uid: uid)
    }

    func handleAccountMismatchFromExistingUserResolution() {
        guard let delegate else { return }
        delegate.awaitingCloudSync = false
        delegate.pendingExistingUserSignIn = false
        presentAccountProfileMismatch()
    }

    // MARK: - Teardown

    func resetConflictStateForSignedOutTransition() {
        guard let delegate else { return }
        delegate.conflictCloudDocument = nil
        delegate.isResolvingProfileConflict = false
        delegate.retryFromAccountMismatch = false
        delegate.pendingUploadFailureContext = nil
        delegate.isRetryingCloudUpload = false
    }

    func resetConflictPresentationState() {
        guard let delegate else { return }
        delegate.isResolvingAccountMismatch = false
        delegate.isResolvingProfileConflict = false
        delegate.showUseDeviceProfileConfirmation = false
        delegate.showUseDevicePlanOverwriteConfirmation = false
    }

    // MARK: - Private

    private func clearStaleOnboardingDraftIfSafe() {
        guard OnboardingDraftPolicy.shouldClearStaleDraftAfterExistingUserRestore(
            hasPersistedDraft: container.onboardingDraftStore.hasDraft
        ) else {
            return
        }
        container.onboardingDraftStore.clearDraft()
    }
}
