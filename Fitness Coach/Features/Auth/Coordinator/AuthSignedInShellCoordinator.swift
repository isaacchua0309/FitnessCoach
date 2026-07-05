//
//  AuthSignedInShellCoordinator.swift
//  Fitness Coach
//
//  Post-sign-in bootstrap, signed-in session state, and root/auth reactions for the auth gate shell.
//

import Foundation

@MainActor
protocol AuthSignedInShellCoordinatorDelegate: AnyObject {
    var signedInSessionID: UUID { get set }
    var awaitingCloudSync: Bool { get set }
    var suppressSignOutEntrySourceAnnotation: Bool { get set }
    var lastExistingUserResolutionResult: ExistingUserSignInResolutionResult? { get set }
    var pendingExistingUserSignIn: Bool { get set }
    var existingUserSignInSessionActive: Bool { get set }
    var existingUserSignInError: ExistingUserSignInFailureKind? { get set }
    var pendingSignInForOnboardingCompletion: Bool { get }
    var publicEntryDestination: PublicEntryRoute { get }

    func clearTestingSignedInUID()
    func isUIDStillCurrent(_ uid: String) -> Bool
    func resetPublicEntryDestinationOnSignIn()
    func handleExistingUserSignInAttemptIfNeeded(from: AuthState, to: AuthState)
    func handleOnboardingSignInAttemptFailedIfNeeded(from: AuthState, to: AuthState)
    func bootstrapOnboardingIfNeeded()
    func resetPublicEntryFlagsForAccountDeletion()
    func applyPublicEntryDestinationAfterSignOut()
    func applyWasSignedInPublicEntryReset()
    func applyColdLaunchPublicEntryDestinationIfNeeded() -> Bool
    func applyExplicitSignOutWelcomeIfNeeded()
    func resetOnboardingForSignedOutTransition()
    func resetOnboardingForAuthenticatedSignOut()
    func clearOnboardingModelIfPolicyRequires(wasSignedIn: Bool)
    func clearOnboardingModel()
    func clearExistingUserSessionForMissingCloudProfile()
    func completeExistingUserSignInSuccessIfNeeded()
    func completeExistingUserSignInNoProfileIfNeeded()
    func logExistingUserSignIn(
        _ event: PublicEntryAnalyticsEvent,
        reason: ExistingUserSignInFailureKind?,
        profileResolutionResult: ExistingUserSignInResolutionResult?
    )
    func resolveOnboardingCompletionAfterSignIn(uid: String) async
    func finishOnboardingCompletionAfterSuccessfulSync()
    func commitLocalProfileForSavePlan()
    func finalizeAfterRestoredExistingPlanAndClearCompletionState()
    func finalizeAfterSuccessfulSignInAndClearCompletionState()
    func retryOnboardingCompletionCloudCheck()
}

@MainActor
final class AuthSignedInShellCoordinator {

    private weak var delegate: AuthSignedInShellCoordinatorDelegate?
    private let container: AppContainer
    private let authManager: AuthManager
    private let rootModel: RootModel
    private let profileConflictCoordinator: AuthProfileConflictCoordinator
    private let restoreShellCoordinator: AuthRestoreShellCoordinator

    init(
        container: AppContainer,
        authManager: AuthManager,
        rootModel: RootModel,
        profileConflictCoordinator: AuthProfileConflictCoordinator,
        restoreShellCoordinator: AuthRestoreShellCoordinator
    ) {
        self.container = container
        self.authManager = authManager
        self.rootModel = rootModel
        self.profileConflictCoordinator = profileConflictCoordinator
        self.restoreShellCoordinator = restoreShellCoordinator
    }

    func configure(delegate: AuthSignedInShellCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Signed-in flow

    func signOutFromAccount() {
        performUserInitiatedSignOut(source: "account_settings")
    }

    func wireAccountDeletionRouter() {
        let router = container.accountDeletionRouter
        router.onFullAccountDeletion = { [weak self] in
            self?.handleAccountDeletionCompleted(scope: .fullAccount)
        }
        router.onLocalDeviceOnlyWipe = { [weak self] in
            self?.handleAccountDeletionCompleted(scope: .localDeviceOnly)
        }
    }

    func handleAccountDeletionCompleted(scope: AccountDeletionScope) {
        resetShellAfterAccountDeletion(source: deletionSource(for: scope))
    }

    func syncUnsyncedLocalProfile(uid: String) {
        guard let delegate else { return }
        delegate.awaitingCloudSync = true
        rootModel.beginCloudSync()

        Task { @MainActor in
            do {
                try await container.profileBootstrapCoordinatorService.syncLocalProfileToCloud(uid: uid)
                delegate.awaitingCloudSync = false
                rootModel.endCloudSync()
                restoreShellCoordinator.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
            } catch {
                delegate.awaitingCloudSync = false
                rootModel.endCloudSync()
                ProfileBootstrapDebugLogger.error(
                    "onboarding_cloud_sync_failed",
                    fields: ["uid": uid, "context": "reconcile"],
                    underlying: error
                )
                presentCloudProfileUploadFailure(context: .reconcileUpload)
            }
        }
    }

    private func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext) {
        profileConflictCoordinator.presentCloudProfileUploadFailure(context: context)
    }

    // MARK: - Auth / root reactions

    func handleAuthStateChange(from previous: AuthState, to state: AuthState) {
        let wasSignedIn = AppRouteResolver.isSignedIn(previous)
        let isSignedInNow = AppRouteResolver.isSignedIn(state)

        if isSignedInNow {
            delegate?.resetPublicEntryDestinationOnSignIn()
            let isFreshSignIn = AppRouteResolver.shouldRotateSignedInSession(
                wasSignedIn: wasSignedIn,
                isSignedIn: isSignedInNow
            )
            if isFreshSignIn {
                delegate?.signedInSessionID = UUID()
            }
            if isSignedInNow, case .signedIn(let uid) = state {
                reconcileSignedInProfile(uid: uid, isFreshSignIn: isFreshSignIn)
            }
        } else {
            handleSignedOutTransition(from: previous, to: state, wasSignedIn: wasSignedIn)
        }

        delegate?.bootstrapOnboardingIfNeeded()
    }

    func handleSignedOutTransition(
        from previous: AuthState,
        to state: AuthState,
        wasSignedIn: Bool
    ) {
        delegate?.handleExistingUserSignInAttemptIfNeeded(from: previous, to: state)
        delegate?.handleOnboardingSignInAttemptFailedIfNeeded(from: previous, to: state)

        if wasSignedIn {
            delegate?.clearTestingSignedInUID()
            container.accountSyncCoordinator.cancelPendingWork()
            container.accountRestoreSessionState.clearForSignOut()
            clearAuthenticatedSessionPresentationState()
            delegate?.resetOnboardingForSignedOutTransition()
            delegate?.pendingExistingUserSignIn = false
            delegate?.existingUserSignInSessionActive = false
            profileConflictCoordinator.resetConflictStateForSignedOutTransition()
            delegate?.awaitingCloudSync = false
            delegate?.signedInSessionID = UUID()
            container.cloudUploadFailureNotifier.clear()
            Task { await container.recordSignedOutLocalUserDataNamespace() }
            AuthLogoutPolicy.clearTransientSessionMetadata(
                cloudSyncStore: container.profileCloudSyncStore
            )
            if delegate?.suppressSignOutEntrySourceAnnotation == false,
               container.publicEntrySessionStore.pendingEntrySource == nil {
                container.publicEntrySessionStore.markSessionExpiredLogout()
            }
            delegate?.suppressSignOutEntrySourceAnnotation = false
            delegate?.applyWasSignedInPublicEntryReset()
            rootModel.resetForSignedOutSession()
            AuthLogoutPolicy.prepareForSignOut(
                sessionStore: container.publicEntrySessionStore,
                source: "auth_state_signed_out_transition",
                wasSignedIn: true,
                hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
                hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
                publicEntryDestination: delegate?.publicEntryDestination ?? .welcome
            )
        } else if delegate?.applyColdLaunchPublicEntryDestinationIfNeeded() == true {
            // Cold-launch public entry resume handled by public-entry flow.
        } else {
            delegate?.applyExplicitSignOutWelcomeIfNeeded()
            rootModel.resetForSignedOutSession()
        }

        delegate?.clearOnboardingModelIfPolicyRequires(wasSignedIn: wasSignedIn)
    }

    func prepareAuthenticatedSignOut(source: String) {
        guard AppRouteResolver.isSignedIn(authManager.authState) else { return }
        container.stopCrossDeviceSyncSession()
        container.accountRestoreSessionState.clearForSignOut()
        clearAuthenticatedSessionPresentationState()
        delegate?.signedInSessionID = UUID()
        delegate?.resetOnboardingForAuthenticatedSignOut()
        delegate?.resetPublicEntryFlagsForAccountDeletion()
        delegate?.awaitingCloudSync = false
        delegate?.applyPublicEntryDestinationAfterSignOut()
        rootModel.resetForSignedOutSession()
        AuthLogoutPolicy.prepareForSignOut(
            sessionStore: container.publicEntrySessionStore,
            source: source,
            wasSignedIn: true,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            publicEntryDestination: delegate?.publicEntryDestination ?? .welcome
        )
    }

    func reconcileSignedInProfile(uid: String, isFreshSignIn: Bool) {
        Task {
            await container.prepareSignedInAccountNamespace(uid: uid)
            guard delegate?.isUIDStillCurrent(uid) == true else { return }

            if delegate?.existingUserSignInSessionActive == true,
               delegate?.pendingSignInForOnboardingCompletion == false {
                await runExistingUserSignInResolution(uid: uid, isFreshSignIn: isFreshSignIn)
                return
            }

            let decision = container.profileBootstrapCoordinatorService.reconcileDecision(
                uid: uid,
                pendingOnboardingCompletion: delegate?.pendingSignInForOnboardingCompletion ?? false,
                pendingExistingUserSignIn: delegate?.pendingExistingUserSignIn ?? false,
                isFreshSignIn: isFreshSignIn,
                rootState: rootModel.state
            )
            applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
        }
    }

    func handleRootStateChange(_ state: RootViewState) {
        if state == .main {
            delegate?.completeExistingUserSignInSuccessIfNeeded()
        }

        if state == .missingCloudProfile {
            delegate?.clearOnboardingModel()
            delegate?.clearExistingUserSessionForMissingCloudProfile()
        }

        if state == .accountProfileMismatch {
            delegate?.clearOnboardingModel()
        }

        if state == .onboarding {
            delegate?.bootstrapOnboardingIfNeeded()
        }
    }

    // MARK: - Account restore routing

    func runExistingUserSignInResolution(uid: String, isFreshSignIn: Bool) async {
        delegate?.pendingExistingUserSignIn = true
        rootModel.beginOnboardingCompletionCloudCheck()

        let outcome = await container.profileBootstrapCoordinatorService.resolveExistingUserSignIn(
            uid: uid,
            isFreshSignIn: isFreshSignIn,
            rootState: rootModel.state
        )

        switch outcome {
        case .resolution(let result):
            applyExistingUserSignInResolution(result, uid: uid)
        case .accountMismatch:
            profileConflictCoordinator.handleAccountMismatchFromExistingUserResolution()
        }
    }

    func applyExistingUserSignInResolution(
        _ result: ExistingUserSignInResolutionResult,
        uid: String
    ) {
        guard let delegate else { return }
        delegate.lastExistingUserResolutionResult = result
        switch result {
        case .profileFound:
            clearStaleOnboardingDraftIfSafe()
            delegate.clearOnboardingModel()
            restoreShellCoordinator.scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
        case .noProfileFound:
            delegate.clearOnboardingModel()
            delegate.awaitingCloudSync = false
            delegate.completeExistingUserSignInNoProfileIfNeeded()
            delegate.pendingExistingUserSignIn = false
            rootModel.presentMissingCloudProfile()
        case .lookupFailed:
            delegate.logExistingUserSignIn(
                .existingSignInFailed,
                reason: .profileLookupFailed,
                profileResolutionResult: .lookupFailed
            )
            delegate.existingUserSignInSessionActive = false
            delegate.pendingExistingUserSignIn = false
            delegate.awaitingCloudSync = false
            rootModel.presentExistingUserProfileLookupFailed()
        case .conflict:
            profileConflictCoordinator.handleExistingUserSignInConflict(uid: uid)
        }
    }

    func retryExistingUserProfileResolution() {
        guard let uid = authManager.currentUID else { return }
        delegate?.existingUserSignInSessionActive = true
        delegate?.existingUserSignInError = nil
        Task {
            await container.prepareSignedInAccountNamespace(uid: uid)
            guard delegate?.isUIDStillCurrent(uid) == true else { return }
            await runExistingUserSignInResolution(uid: uid, isFreshSignIn: false)
        }
    }

    func applyReconcileDecision(
        _ decision: SignedInProfileReconcileDecision,
        uid: String,
        isFreshSignIn: Bool
    ) {
        guard let delegate else { return }
        switch decision {
        case .resolveOnboardingCompletion(let uid):
            Task { await delegate.resolveOnboardingCompletionAfterSignIn(uid: uid) }
        case .routeToMain:
            restoreShellCoordinator.scheduleRouteToMainWithAccountRestore(
                uid: uid,
                reason: isFreshSignIn ? .afterSignIn : .appLaunch
            )
        case .syncLocalProfileToCloud(let uid):
            syncUnsyncedLocalProfile(uid: uid)
        case .loadCloudProfile(let uid):
            if rootModel.state == .onboarding {
                delegate.clearOnboardingModel()
            }
            delegate.awaitingCloudSync = false
            Task {
                let bootstrapState = await rootModel.loadAwaitingCompletion(uid: uid)
                guard delegate.isUIDStillCurrent(uid) else { return }
                switch bootstrapState {
                case .main:
                    restoreShellCoordinator.routeToMainWithAccountRestore(
                        uid: uid,
                        reason: isFreshSignIn ? .afterSignIn : .appLaunch
                    )
                case .missingCloudProfile:
                    delegate.completeExistingUserSignInNoProfileIfNeeded()
                    delegate.pendingExistingUserSignIn = false
                default:
                    break
                }
            }
        case .requireOwnershipCloudLookup(let uid):
            performOwnershipCloudLookup(uid: uid, isFreshSignIn: isFreshSignIn)
        case .showAccountMismatch:
            profileConflictCoordinator.presentAccountProfileMismatch()
        case .showProfileConflict(let uid):
            profileConflictCoordinator.presentProfileConflictAfterLookup(uid: uid)
        case .showCloudFetchFailed:
            rootModel.presentOnboardingCloudCheckFailed()
        case .presentMissingCloudProfile:
            delegate.clearOnboardingModel()
            delegate.awaitingCloudSync = false
            delegate.completeExistingUserSignInNoProfileIfNeeded()
            delegate.pendingExistingUserSignIn = false
            rootModel.presentMissingCloudProfile()
        case .skip:
            break
        }
    }

    func performOwnershipCloudLookup(uid: String, isFreshSignIn: Bool) {
        Task { @MainActor in
            guard let delegate else { return }
            let cloudResult = await container.profileBootstrapCoordinatorService.ownershipCloudLookup(
                uid: uid,
                context: .ownershipResolution
            )
            let decision = container.profileBootstrapCoordinatorService.reconcileDecision(
                uid: uid,
                pendingOnboardingCompletion: delegate.pendingSignInForOnboardingCompletion,
                pendingExistingUserSignIn: delegate.pendingExistingUserSignIn,
                isFreshSignIn: isFreshSignIn,
                rootState: rootModel.state,
                cloudResult: cloudResult
            )
            applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
        }
    }

    func retryProfileLoad() {
        guard case .signedIn(let uid) = authManager.authState else { return }
        rootModel.retry(uid: uid)
    }

    // MARK: - Private

    private func deletionSource(for scope: AccountDeletionScope) -> String {
        switch scope {
        case .fullAccount:
            return "account_deletion"
        case .localDeviceOnly:
            return "local_device_data_wipe"
        case .remoteAccountDataOnly:
            return "remote_account_data_deletion"
        }
    }

    private func resetShellAfterAccountDeletion(source: String) {
        container.publicEntrySessionStore.markUserInitiatedLogout()
        container.stopCrossDeviceSyncSession()
        container.accountRestoreSessionState.clearForSignOut()
        clearAuthenticatedSessionPresentationState()
        delegate?.signedInSessionID = UUID()
        delegate?.resetOnboardingForAuthenticatedSignOut()
        delegate?.resetPublicEntryFlagsForAccountDeletion()
        delegate?.awaitingCloudSync = false
        delegate?.applyPublicEntryDestinationAfterSignOut()
        rootModel.resetForSignedOutSession()
        AuthLogoutPolicy.prepareForSignOut(
            sessionStore: container.publicEntrySessionStore,
            source: source,
            wasSignedIn: true,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            publicEntryDestination: delegate?.publicEntryDestination ?? .welcome
        )
    }

    private func performUserInitiatedSignOut(source: String) {
        container.publicEntrySessionStore.markUserInitiatedLogout()
        prepareAuthenticatedSignOut(source: source)
        authManager.signOut()
    }

    private func clearAuthenticatedSessionPresentationState() {
        restoreShellCoordinator.cancelRestorePresentation()
        profileConflictCoordinator.resetConflictPresentationState()
        delegate?.lastExistingUserResolutionResult = nil
        container.onboardingCoachingContextStore.clear()
    }

    private func clearStaleOnboardingDraftIfSafe() {
        guard OnboardingDraftPolicy.shouldClearStaleDraftAfterExistingUserRestore(
            hasPersistedDraft: container.onboardingDraftStore.hasDraft
        ) else {
            return
        }
        container.onboardingDraftStore.clearDraft()
    }
}
