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
    var conflictCloudDocument: CloudUserProfileDocument? { get set }
    var profileConflictContext: ProfileConflictResolutionContext { get set }
    var isResolvingProfileConflict: Bool { get set }
    var showUseDevicePlanOverwriteConfirmation: Bool { get set }
    var isResolvingAccountMismatch: Bool { get set }
    var showUseDeviceProfileConfirmation: Bool { get set }
    var retryFromAccountMismatch: Bool { get set }
    var pendingUploadFailureContext: CloudProfileUploadFailureContext? { get set }
    var isRetryingCloudUpload: Bool { get set }
    var suppressSignOutEntrySourceAnnotation: Bool { get set }
    var lastExistingUserResolutionResult: ExistingUserSignInResolutionResult? { get set }
    var accountRestoreViewModel: AccountRestoreViewModel? { get set }
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
    private var accountRestoreRouteTask: Task<Void, Never>?

    init(container: AppContainer, authManager: AuthManager, rootModel: RootModel) {
        self.container = container
        self.authManager = authManager
        self.rootModel = rootModel
    }

    func configure(delegate: AuthSignedInShellCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Signed-in flow

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
                scheduleRouteToMainWithAccountRestore(uid: uid, reason: .accountSwitch)
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
                scheduleRouteToMainWithAccountRestore(uid: uid, reason: .accountSwitch)
            } catch {
                delegate?.isResolvingAccountMismatch = false
                delegate?.retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func signOutFromAccountMismatch() {
        performUserInitiatedSignOut(source: "account_profile_mismatch")
    }

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

    func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext) {
        guard let delegate else { return }
        delegate.pendingUploadFailureContext = context
        container.profileCloudSyncStore.clear()
        container.cloudUploadFailureNotifier.clear()
        delegate.awaitingCloudSync = false
        rootModel.presentCloudProfileUploadFailed()
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
        scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
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
        scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
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
                scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
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
            scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
        case .conflictReplace:
            finishProfileConflictAfterUpload()
        case .profileEdit:
            delegate.awaitingCloudSync = false
            guard let uid = authManager.currentUID else { return }
            scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
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
        scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
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
            delegate?.conflictCloudDocument = nil
            delegate?.isResolvingProfileConflict = false
            delegate?.pendingUploadFailureContext = nil
            delegate?.isRetryingCloudUpload = false
            delegate?.retryFromAccountMismatch = false
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

    func routeToMainWithAccountRestore(uid: String, reason: AccountRestoreReason) {
        guard AccountRestoreCoordinatorSupport.isRestoreEnabled else {
            completeRouteToMain(uid: uid)
            return
        }

        container.accountRestoreSessionState.beginBlockingRestore()
        let viewModel = delegate?.accountRestoreViewModel ?? makeAccountRestoreViewModel()
        delegate?.accountRestoreViewModel = viewModel
        rootModel.beginAccountRestore(uid: uid)
        viewModel.start(uid: uid, reason: reason)
    }

    func completeRouteToMain(uid: String, restoreSummary: AccountRestoreSummary? = nil) {
        guard delegate?.isUIDStillCurrent(uid) == true else { return }
        delegate?.awaitingCloudSync = false
        delegate?.completeExistingUserSignInSuccessIfNeeded()
        delegate?.pendingExistingUserSignIn = false
        try? container.actionCenter.syncTodayTargetsFromProfile()
        container.onboardingCoachingContextStore.clear()
        if let restoreSummary {
            container.accountRestoreSessionState.recordRestoreCompletion(restoreSummary)
            container.refreshCenter.notifyAccountRestoreDidComplete()
        }
        rootModel.didEnterSignedInMainShell(uid: uid)
        container.handleSignedInSessionReady(uid: uid)
        rootModel.didCompleteOnboarding()
    }

    func scheduleRouteToMainWithAccountRestore(uid: String, reason: AccountRestoreReason) {
        accountRestoreRouteTask?.cancel()
        accountRestoreRouteTask = Task { @MainActor in
            guard delegate?.isUIDStillCurrent(uid) == true else { return }
            routeToMainWithAccountRestore(uid: uid, reason: reason)
        }
    }

    func retryAccountRestore() {
        delegate?.accountRestoreViewModel?.retry()
    }

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
            delegate?.awaitingCloudSync = false
            delegate?.pendingExistingUserSignIn = false
            rootModel.presentAccountProfileMismatch()
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
            scheduleRouteToMainWithAccountRestore(uid: uid, reason: .afterSignIn)
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
            delegate.awaitingCloudSync = false
            delegate.pendingExistingUserSignIn = false
            delegate.profileConflictContext = .accountOrOwnershipReconcile
            presentProfileConflictAfterLookup(uid: uid)
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
            scheduleRouteToMainWithAccountRestore(
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
                    await routeToMainWithAccountRestore(
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
            delegate.awaitingCloudSync = false
            rootModel.presentAccountProfileMismatch()
        case .showProfileConflict(let uid):
            presentProfileConflictAfterLookup(uid: uid)
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
        accountRestoreRouteTask?.cancel()
        accountRestoreRouteTask = nil
        delegate?.accountRestoreViewModel = nil
        delegate?.isResolvingAccountMismatch = false
        delegate?.isResolvingProfileConflict = false
        delegate?.showUseDeviceProfileConfirmation = false
        delegate?.showUseDevicePlanOverwriteConfirmation = false
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

    private func makeAccountRestoreViewModel() -> AccountRestoreViewModel {
        let viewModel = AccountRestoreViewModel(container: container)
        viewModel.onContinueToMain = { [weak self] summary in
            guard let self, let uid = self.authManager.currentUID else { return }
            self.delegate?.accountRestoreViewModel = nil
            self.completeRouteToMain(uid: uid, restoreSummary: summary)
        }
        viewModel.onSignOut = { [weak self] in
            guard let self else { return }
            self.delegate?.accountRestoreViewModel = nil
            self.prepareAuthenticatedSignOut(source: "account_restore_failed_sign_out")
            self.authManager.signOut()
        }
        return viewModel
    }
}
