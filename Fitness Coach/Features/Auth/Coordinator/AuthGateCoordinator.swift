//
//  AuthGateCoordinator.swift
//  Fitness Coach
//
//  Auth-gated shell orchestration extracted from AuthGateView.
//

import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AuthGateCoordinator: ObservableObject {

    let container: AppContainer
    let authManager: AuthManager
    let rootModel: RootModel

    @Published var onboardingModel: OnboardingModel?
    @Published var signedInSessionID = UUID()
    @Published var pendingSignInForOnboardingCompletion = false
    @Published var pendingExistingUserSignIn = false
    @Published var existingUserSignInSessionActive = false
    @Published var existingUserSignInError: ExistingUserSignInFailureKind?
    @Published var returnToExistingUserSignInAfterSignOut = false
    @Published var publicEntryDestination: PublicEntryRoute = .welcome
    @Published var conflictCloudDocument: CloudUserProfileDocument?
    @Published var profileConflictContext: ProfileConflictResolutionContext = .accountOrOwnershipReconcile
    @Published var isResolvingProfileConflict = false
    @Published var showUseDevicePlanOverwriteConfirmation = false
    @Published var isResolvingAccountMismatch = false
    @Published var showUseDeviceProfileConfirmation = false
    @Published var retryFromAccountMismatch = false
    @Published var awaitingCloudSync = false
    @Published var pendingUploadFailureContext: CloudProfileUploadFailureContext?
    @Published var isRetryingCloudUpload = false
    @Published var didLogColdStartWelcome = false
    @Published var suppressSignOutEntrySourceAnnotation = false
    @Published var lastExistingUserResolutionResult: ExistingUserSignInResolutionResult?

    private var cancellables = Set<AnyCancellable>()
    private var onboardingModelCancellable: AnyCancellable?

    init(container: AppContainer) {
        self.container = container
        self.authManager = container.authManager
        self.rootModel = container.makeRootModel()

        rootModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func bindOnboardingModelChanges() {
        onboardingModelCancellable = onboardingModel?.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // MARK: - Routing

    var effectiveRoute: AppShellRoute {
        let suppressAutomaticPublicEntryResume =
            container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
        let base = container.resolveAppShellRoute(
            authState: authManager.authState,
            rootState: rootModel.state,
            isOnboardingModelReady: onboardingModel != nil,
            awaitingCloudSync: awaitingCloudSync,
            pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
            publicEntryDestination: publicEntryDestination
        )
        return AuthGateRoutingPolicy.effectiveRoute(
            baseRoute: base,
            isSignedIn: AppRouteResolver.isSignedIn(authManager.authState),
            hasActiveOnboardingSession: onboardingModel != nil,
            suppressAutomaticPublicEntryResume: suppressAutomaticPublicEntryResume
        )
    }

    // MARK: - Public entry actions

    func beginOnboardingFromWelcome() {
        startPreAuthOnboarding()
    }

    func beginExistingUserSignInFromWelcome() {
        onboardingModel = nil
        existingUserSignInError = nil
        publicEntryDestination = .existingUserSignIn
    }

    func returnToWelcomeFromExistingUserSignIn() {
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
        publicEntryDestination = .welcome
    }

    func returnToWelcomeFromOnboarding() {
        onboardingModel = nil
        container.onboardingDraftStore.clearDraft()
        publicEntryDestination = .welcome
    }

    func beginOnboardingFromExistingUserSignIn() {
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
        startPreAuthOnboarding()
    }

    func startPreAuthOnboarding() {
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        container.publicEntrySessionStore.clearExplicitSignOut()
        publicEntryDestination = WelcomeOnboardingHandoffPolicy.createPlanDestination
        onboardingModel = nil
        rootModel.resolveLocalProfile()
        ensurePreAuthOnboardingModel()
    }

    func signInAsExistingUser() {
        existingUserSignInError = nil
        pendingExistingUserSignIn = true
        existingUserSignInSessionActive = true
        logExistingUserSignIn(.existingSignInStarted)
        Task {
            await authManager.signInWithGoogle()
        }
    }

    func beginOnboardingAfterNoExistingPlan() {
        onboardingModel = nil
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        rootModel.continueFromMissingCloudProfile()
        ensureOnboardingModel()
    }

    func useAnotherAccountAfterNoExistingPlan() {
        returnToExistingUserSignInAfterSignOut = true
        existingUserSignInSessionActive = false
        pendingExistingUserSignIn = false
        existingUserSignInError = nil
        onboardingModel = nil
        suppressSignOutEntrySourceAnnotation = true
        prepareAuthenticatedSignOut(source: "no_existing_profile_use_another_account")
        authManager.signOut()
    }

    // MARK: - Pre-auth onboarding

    func preparePreAuthOnboardingIfNeeded() {
        guard !AppRouteResolver.isSignedIn(authManager.authState) else { return }
        rootModel.resolveLocalProfile()
        if publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination {
            ensurePreAuthOnboardingModel()
        } else {
            ensureOnboardingModel()
        }
    }

    // MARK: - Signed-in flow

    func restoreGoogleAccountPlanAfterMismatch() {
        guard let uid = authManager.currentUID else { return }

        isResolvingAccountMismatch = true

        Task { @MainActor in
            let outcome = await container.profileBootstrapCoordinatorService.restoreGoogleAccountPlan(uid: uid)

            switch outcome {
            case .restoredToMain:
                try? container.dailyLogService.syncTodayTargetsFromProfile()
                container.onboardingCoachingContextStore.clear()
                isResolvingAccountMismatch = false
                awaitingCloudSync = false
                rootModel.didCompleteOnboarding()
            case .missingCloudProfile:
                isResolvingAccountMismatch = false
                onboardingModel = nil
                rootModel.presentMissingCloudProfile()
            case .cloudFetchFailed:
                isResolvingAccountMismatch = false
                retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func beginUseDeviceProfileAfterMismatch() {
        guard let uid = authManager.currentUID else { return }

        isResolvingAccountMismatch = true

        Task { @MainActor in
            let outcome = await container.profileBootstrapCoordinatorService.prepareUseDeviceProfile(uid: uid)
            isResolvingAccountMismatch = false

            switch outcome {
        case .cloudProfileConflict(let document):
            conflictCloudDocument = document
            profileConflictContext = .onboardingCompletion
            rootModel.presentProfilePlanConflict()
            case .requiresLocalLinkConfirmation:
                showUseDeviceProfileConfirmation = true
            case .cloudFetchFailed:
                retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func confirmUseDeviceProfileAfterPrompt() {
        guard let uid = authManager.currentUID else { return }

        isResolvingAccountMismatch = true

        Task { @MainActor in
            do {
                _ = try container.profileBootstrapCoordinatorService.confirmLinkLocalProfileToAccount(uid: uid)
                isResolvingAccountMismatch = false
                awaitingCloudSync = false
                rootModel.didCompleteOnboarding()
            } catch {
                isResolvingAccountMismatch = false
                retryFromAccountMismatch = true
                rootModel.presentAccountMismatchCloudCheckFailed()
            }
        }
    }

    func signOutFromAccountMismatch() {
        container.publicEntrySessionStore.markUserInitiatedLogout()
        prepareAuthenticatedSignOut(source: "account_profile_mismatch")
        authManager.signOut()
    }

    func retryAccountMismatchOrOnboardingCloudCheck() {
        if retryFromAccountMismatch {
            retryFromAccountMismatch = false
            rootModel.presentAccountProfileMismatch()
            restoreGoogleAccountPlanAfterMismatch()
            return
        }
        retryOnboardingCompletionCloudCheck()
    }

    // MARK: - Onboarding model lifecycle

    /// Ensures the onboarding model exists whenever routing targets an initializing onboarding shell.
    /// Without this, `.onboardingInitializing` shows only
    /// `LaunchLoadingView` and never reach the views whose `onAppear` used to create the model.
    func bootstrapOnboardingIfNeeded() {
        let signedIn = AppRouteResolver.isSignedIn(authManager.authState)

        let hasLocalProfile = container.profileBootstrapService.hasLocalProfile()
        let awaitingSignInHandoff = container.profileBootstrapService.localProfileAwaitingSignIn()
        let shouldBootstrapPreAuth = !signedIn && (
            publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination
                || WelcomeOnboardingHandoffPolicy.shouldBypassWelcome(
                    PublicEntryRouteResolver.Input(
                        destination: publicEntryDestination,
                        isOnboardingModelReady: onboardingModel != nil,
                        localProfileAwaitingSignIn: awaitingSignInHandoff,
                        hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
                        hasLocalProfile: hasLocalProfile,
                        pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
                        signedOutWithProfilePolicy: .requireSignIn,
                        suppressAutomaticPublicEntryResume:
                            container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
                    )
                )
        )

        let needsSignedInOnboarding = signedIn && rootModel.state == .onboarding

        if shouldBootstrapPreAuth {
            rootModel.resolveLocalProfile()
            if publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination {
                ensurePreAuthOnboardingModel()
            } else {
                ensureOnboardingModel()
            }
        }

        if needsSignedInOnboarding {
            ensureOnboardingModel()
        }
    }

    func ensurePreAuthOnboardingModel() {
        guard onboardingModel == nil else { return }
        onboardingModel = container.makeOnboardingModel(
            entry: WelcomeOnboardingHandoffPolicy.preAuthEntry,
            onCompletion: { [weak self] in self?.handleOnboardingCompletionRequest() }
        )
        bindOnboardingModelChanges()
    }

    func ensureOnboardingModel() {
        guard onboardingModel == nil else { return }
        let entry = NoExistingProfileFoundPolicy.onboardingEntry(
            isSignedIn: AppRouteResolver.isSignedIn(authManager.authState)
        )
        onboardingModel = container.makeOnboardingModel(entry: entry) { [weak self] in
            self?.handleOnboardingCompletionRequest()
        }
        bindOnboardingModelChanges()
    }

    func handleOnboardingCompletionRequest() {
        if onboardingModel?.pendingCompletionIntent == .localOnly {
            finishOnboardingAfterLocalSkip()
            return
        }

        if AppRouteResolver.isSignedIn(authManager.authState) {
            guard let uid = authManager.currentUID else {
                finishOnboardingLocally()
                return
            }
            Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
            return
        }

        pendingSignInForOnboardingCompletion = true
        onboardingModel?.beginSignInForCompletion()
        Task {
            await authManager.signInWithGoogle()
        }
    }

    /// Signed-in onboarding completion: probe cloud, then sync or show conflict UI.
    func resolveOnboardingCompletionAfterSignIn(uid: String) async {
        rootModel.beginOnboardingCompletionCloudCheck()

        let outcome = await container.profileBootstrapCoordinatorService.resolveOnboardingCompletion(uid: uid)

        switch outcome {
        case .uploadedToCloud:
            finishOnboardingCompletionAfterSuccessfulSync()
        case .cloudProfileConflict(let document):
            conflictCloudDocument = document
            profileConflictContext = .accountOrOwnershipReconcile
            rootModel.presentProfilePlanConflict()
        case .cloudCheckFailed:
            rootModel.presentOnboardingCloudCheckFailed()
        case .cloudSyncFailed:
            presentCloudProfileUploadFailure(context: .onboardingCompletion)
        }
    }

    func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext) {
        pendingUploadFailureContext = context
        container.profileCloudSyncStore.clear()
        container.cloudUploadFailureNotifier.clear()
        awaitingCloudSync = false
        rootModel.presentCloudProfileUploadFailed()
    }

    func finishOnboardingCompletionAfterSuccessfulSync() {
        OnboardingLocalCompletionMarker.clear()
        onboardingModel?.markSignInSucceededForHandoff()

        Task { @MainActor in
            let handoffDelayNanoseconds: UInt64 = UIAccessibility.isReduceMotionEnabled
                ? 280_000_000
                : 720_000_000
            try? await Task.sleep(nanoseconds: handoffDelayNanoseconds)
            clearOnboardingCompletionState()
            awaitingCloudSync = false
            rootModel.didCompleteOnboarding()
        }
    }

    func clearProfileConflictState() {
        conflictCloudDocument = nil
        isResolvingProfileConflict = false
        profileConflictContext = .accountOrOwnershipReconcile
    }

    func clearOnboardingCompletionState() {
        pendingSignInForOnboardingCompletion = false
        clearProfileConflictState()
        onboardingModel = nil
    }

    func restoreExistingPlanAfterConflict() {
        guard let cloudDocument = conflictCloudDocument,
              let uid = authManager.currentUID else { return }

        isResolvingProfileConflict = true

        Task { @MainActor in
            do {
                _ = try container.profileBootstrapCoordinatorService.restoreExistingPlanAfterConflict(
                    uid: uid,
                    cloudDocument: cloudDocument
                )
                try container.dailyLogService.syncTodayTargetsFromProfile()
                container.onboardingCoachingContextStore.clear()
                finishProfileConflictAfterRestore()
            } catch {
                isResolvingProfileConflict = false
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
        showUseDevicePlanOverwriteConfirmation = true
    }

    func confirmUseDevicePlanAfterConflict() {
        guard let uid = authManager.currentUID else { return }

        isResolvingProfileConflict = true

        Task { @MainActor in
            do {
                try await container.profileBootstrapCoordinatorService.uploadDevicePlanAfterConflict(uid: uid)
                isResolvingProfileConflict = false
                finishProfileConflictAfterUpload()
            } catch {
                isResolvingProfileConflict = false
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
        switch profileConflictContext {
        case .onboardingCompletion:
            onboardingModel?.finalizeAfterRestoredExistingPlan()
            clearOnboardingCompletionState()
        case .accountOrOwnershipReconcile:
            clearProfileConflictState()
            clearStaleOnboardingDraftIfSafe()
            completeExistingUserSignInSuccessIfNeeded()
        }
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    func finishProfileConflictAfterUpload() {
        switch profileConflictContext {
        case .onboardingCompletion:
            onboardingModel?.finalizeAfterSuccessfulSignIn()
            clearOnboardingCompletionState()
        case .accountOrOwnershipReconcile:
            clearProfileConflictState()
            clearStaleOnboardingDraftIfSafe()
            completeExistingUserSignInSuccessIfNeeded()
        }
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    func retryOnboardingCompletionCloudCheck() {
        guard let uid = authManager.currentUID else { return }
        Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
    }

    func finishOnboardingAfterLocalSkip() {
        OnboardingLocalCompletionMarker.markAcknowledged()
        onboardingModel?.finalizeAfterLocalSkip()
        clearOnboardingCompletionState()
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    func finishOnboardingLocally() {
        onboardingModel?.finalizeAfterSuccessfulSignIn()
        onboardingModel = nil
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    func syncUnsyncedLocalProfile(uid: String) {
        awaitingCloudSync = true
        rootModel.beginCloudSync()

        Task { @MainActor in
            do {
                try await container.profileBootstrapCoordinatorService.syncLocalProfileToCloud(uid: uid)
                awaitingCloudSync = false
                rootModel.endCloudSync()
                rootModel.didCompleteOnboarding()
            } catch {
                awaitingCloudSync = false
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
        guard let uid = authManager.currentUID,
              let context = pendingUploadFailureContext else { return }

        isRetryingCloudUpload = true

        Task { @MainActor in
            defer { isRetryingCloudUpload = false }
            do {
                try await container.profileBootstrapCoordinatorService.retryCloudProfileUpload(
                    uid: uid,
                    context: context
                )
                let succeededContext = context
                pendingUploadFailureContext = nil
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
        switch context {
        case .onboardingCompletion:
            finishOnboardingCompletionAfterSuccessfulSync()
        case .reconcileUpload:
            awaitingCloudSync = false
            rootModel.didCompleteOnboarding()
        case .conflictReplace:
            finishProfileConflictAfterUpload()
        case .profileEdit:
            awaitingCloudSync = false
            rootModel.continueDespiteCloudUploadFailure()
        }
    }

    func continueAfterCloudUploadFailure() {
        let context = pendingUploadFailureContext
        container.profileCloudSyncStore.clear()
        pendingUploadFailureContext = nil
        container.cloudUploadFailureNotifier.clear()

        switch context {
        case .onboardingCompletion:
            onboardingModel?.finalizeAfterSuccessfulSignIn()
            clearOnboardingCompletionState()
        case .reconcileUpload, .conflictReplace:
            clearProfileConflictState()
        case .profileEdit, .none:
            break
        }

        awaitingCloudSync = false
        rootModel.continueDespiteCloudUploadFailure()
    }

    // MARK: - Auth / root reactions

    func handleAuthStateChange(from previous: AuthState, to state: AuthState) {
        let wasSignedIn = AppRouteResolver.isSignedIn(previous)
        let isSignedInNow = AppRouteResolver.isSignedIn(state)

        if isSignedInNow {
            publicEntryDestination = .welcome
            let isFreshSignIn = AppRouteResolver.shouldRotateSignedInSession(
                wasSignedIn: wasSignedIn,
                isSignedIn: isSignedInNow
            )
            if isFreshSignIn {
                signedInSessionID = UUID()
            }
            if isSignedInNow, case .signedIn(let uid) = state {
                reconcileSignedInProfile(uid: uid, isFreshSignIn: isFreshSignIn)
            }
        } else {
            handleSignedOutTransition(from: previous, to: state, wasSignedIn: wasSignedIn)
        }

        bootstrapOnboardingIfNeeded()
    }

    func handleSignedOutTransition(
        from previous: AuthState,
        to state: AuthState,
        wasSignedIn: Bool
    ) {
        if pendingExistingUserSignIn || existingUserSignInSessionActive,
           didSignInAttemptFail(from: previous, to: state) {
            if let failureKind = ExistingUserSignInPolicy.failureKind(from: previous, to: state) {
                completeExistingUserSignInFailure(failureKind)
            }
        }

        if pendingSignInForOnboardingCompletion, didSignInAttemptFail(from: previous, to: state) {
            pendingSignInForOnboardingCompletion = false
            conflictCloudDocument = nil
            isResolvingProfileConflict = false
            let wasCancelled: Bool
            if case .signedOut = state {
                wasCancelled = true
            } else {
                wasCancelled = false
            }
            onboardingModel?.handleSignInCompletionFailure(wasCancelled: wasCancelled)
        }

        if wasSignedIn {
            onboardingModel = nil
            pendingExistingUserSignIn = false
            existingUserSignInSessionActive = false
            pendingSignInForOnboardingCompletion = false
            conflictCloudDocument = nil
            isResolvingProfileConflict = false
            pendingUploadFailureContext = nil
            isRetryingCloudUpload = false
            retryFromAccountMismatch = false
            container.cloudUploadFailureNotifier.clear()
            AuthLogoutPolicy.clearTransientSessionMetadata(
                cloudSyncStore: container.profileCloudSyncStore
            )
            if !suppressSignOutEntrySourceAnnotation,
               container.publicEntrySessionStore.pendingEntrySource == nil {
                container.publicEntrySessionStore.markSessionExpiredLogout()
            }
            suppressSignOutEntrySourceAnnotation = false
            publicEntryDestination = AuthLogoutPolicy.publicEntryDestinationAfterSignOut(
                returnToExistingUserSignIn: returnToExistingUserSignInAfterSignOut,
                hasExistingUserSignInError: existingUserSignInError != nil
            )
            if returnToExistingUserSignInAfterSignOut {
                returnToExistingUserSignInAfterSignOut = false
                existingUserSignInError = nil
            }
            rootModel.resetForSignedOutSession()
            AuthLogoutPolicy.prepareForSignOut(
                sessionStore: container.publicEntrySessionStore,
                source: "auth_state_signed_out_transition",
                wasSignedIn: true,
                hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
                hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
                publicEntryDestination: publicEntryDestination
            )
        } else if let resumedDestination = AuthLogoutPolicy.coldLaunchPublicEntryDestination(
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            suppressAutomaticPublicEntryResume:
                container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
        ) {
            publicEntryDestination = resumedDestination
            rootModel.resolveLocalProfile()
        } else {
            rootModel.resetForSignedOutSession()
        }

        if AppRouteResolver.shouldClearOnboardingModel(
            wasSignedIn: wasSignedIn,
            isSignedIn: false,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft
        ) {
            onboardingModel = nil
        }
    }

    func prepareAuthenticatedSignOut(source: String) {
        guard AppRouteResolver.isSignedIn(authManager.authState) else { return }
        onboardingModel = nil
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        pendingSignInForOnboardingCompletion = false
        publicEntryDestination = AuthLogoutPolicy.publicEntryDestinationAfterSignOut(
            returnToExistingUserSignIn: returnToExistingUserSignInAfterSignOut,
            hasExistingUserSignInError: existingUserSignInError != nil
        )
        rootModel.resetForSignedOutSession()
        AuthLogoutPolicy.prepareForSignOut(
            sessionStore: container.publicEntrySessionStore,
            source: source,
            wasSignedIn: true,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            publicEntryDestination: publicEntryDestination
        )
    }

    func reconcileSignedInProfile(uid: String, isFreshSignIn: Bool) {
        if existingUserSignInSessionActive, !pendingSignInForOnboardingCompletion {
            Task { await runExistingUserSignInResolution(uid: uid, isFreshSignIn: isFreshSignIn) }
            return
        }

        let decision = container.profileBootstrapCoordinatorService.reconcileDecision(
            uid: uid,
            pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
            pendingExistingUserSignIn: pendingExistingUserSignIn,
            isFreshSignIn: isFreshSignIn,
            rootState: rootModel.state
        )
        applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
    }

    @MainActor
    func runExistingUserSignInResolution(uid: String, isFreshSignIn: Bool) async {
        pendingExistingUserSignIn = true
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
            awaitingCloudSync = false
            pendingExistingUserSignIn = false
            rootModel.presentAccountProfileMismatch()
        }
    }

    func applyExistingUserSignInResolution(
        _ result: ExistingUserSignInResolutionResult,
        uid: String
    ) {
        lastExistingUserResolutionResult = result
        switch result {
        case .profileFound:
            clearStaleOnboardingDraftIfSafe()
            onboardingModel = nil
            awaitingCloudSync = false
            completeExistingUserSignInSuccessIfNeeded()
            pendingExistingUserSignIn = false
            try? container.dailyLogService.syncTodayTargetsFromProfile()
            container.onboardingCoachingContextStore.clear()
            rootModel.didCompleteOnboarding()
        case .noProfileFound:
            onboardingModel = nil
            awaitingCloudSync = false
            completeExistingUserSignInNoProfileIfNeeded()
            pendingExistingUserSignIn = false
            rootModel.presentMissingCloudProfile()
        case .lookupFailed:
            logExistingUserSignIn(
                .existingSignInFailed,
                reason: .profileLookupFailed,
                profileResolutionResult: .lookupFailed
            )
            existingUserSignInSessionActive = false
            pendingExistingUserSignIn = false
            awaitingCloudSync = false
            rootModel.presentExistingUserProfileLookupFailed()
        case .conflict:
            awaitingCloudSync = false
            pendingExistingUserSignIn = false
            profileConflictContext = .accountOrOwnershipReconcile
            presentProfileConflictAfterLookup(uid: uid)
        }
    }

    func retryExistingUserProfileResolution() {
        guard let uid = authManager.currentUID else { return }
        existingUserSignInSessionActive = true
        existingUserSignInError = nil
        Task { await runExistingUserSignInResolution(uid: uid, isFreshSignIn: false) }
    }

    func clearStaleOnboardingDraftIfSafe() {
        guard OnboardingDraftPolicy.shouldClearStaleDraftAfterExistingUserRestore(
            hasPersistedDraft: container.onboardingDraftStore.hasDraft
        ) else {
            return
        }
        container.onboardingDraftStore.clearDraft()
    }

    func applyReconcileDecision(
        _ decision: SignedInProfileReconcileDecision,
        uid: String,
        isFreshSignIn: Bool
    ) {
        switch decision {
        case .resolveOnboardingCompletion(let uid):
            Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
        case .routeToMain:
            awaitingCloudSync = false
            completeExistingUserSignInSuccessIfNeeded()
            pendingExistingUserSignIn = false
            rootModel.didCompleteOnboarding()
        case .syncLocalProfileToCloud(let uid):
            syncUnsyncedLocalProfile(uid: uid)
        case .loadCloudProfile(let uid):
            if rootModel.state == .onboarding {
                onboardingModel = nil
            }
            awaitingCloudSync = false
            rootModel.load(uid: uid)
        case .requireOwnershipCloudLookup(let uid):
            performOwnershipCloudLookup(uid: uid, isFreshSignIn: isFreshSignIn)
        case .showAccountMismatch:
            awaitingCloudSync = false
            rootModel.presentAccountProfileMismatch()
        case .showProfileConflict(let uid):
            presentProfileConflictAfterLookup(uid: uid)
        case .showCloudFetchFailed:
            rootModel.presentOnboardingCloudCheckFailed()
        case .presentMissingCloudProfile:
            onboardingModel = nil
            awaitingCloudSync = false
            completeExistingUserSignInNoProfileIfNeeded()
            pendingExistingUserSignIn = false
            rootModel.presentMissingCloudProfile()
        case .skip:
            break
        }
    }

    func performOwnershipCloudLookup(uid: String, isFreshSignIn: Bool) {
        Task { @MainActor in
            let cloudResult = await container.profileBootstrapCoordinatorService.ownershipCloudLookup(
                uid: uid,
                context: .ownershipResolution
            )
            let decision = container.profileBootstrapCoordinatorService.reconcileDecision(
                uid: uid,
                pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
                pendingExistingUserSignIn: pendingExistingUserSignIn,
                isFreshSignIn: isFreshSignIn,
                rootState: rootModel.state,
                cloudResult: cloudResult
            )
            applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
        }
    }

    func presentProfileConflictAfterLookup(uid: String) {
        Task { @MainActor in
            switch await container.profileBootstrapService.resolveCloudProfile(
                uid: uid,
                context: .ownershipResolution
            ) {
            case .found(let document):
                conflictCloudDocument = document
                profileConflictContext = .accountOrOwnershipReconcile
                rootModel.presentProfilePlanConflict()
            case .missing, .failed:
                if existingUserSignInSessionActive {
                    logExistingUserSignIn(
                        .existingSignInFailed,
                        reason: .profileLookupFailed,
                        profileResolutionResult: .lookupFailed
                    )
                    existingUserSignInSessionActive = false
                    rootModel.presentExistingUserProfileLookupFailed()
                } else {
                    rootModel.presentOnboardingCloudCheckFailed()
                }
            }
        }
    }

    func handleRootStateChange(_ state: RootViewState) {
        if state == .main {
            completeExistingUserSignInSuccessIfNeeded()
        }

        if state == .missingCloudProfile {
            onboardingModel = nil
            pendingExistingUserSignIn = false
            existingUserSignInSessionActive = false
        }

        if state == .accountProfileMismatch {
            onboardingModel = nil
        }

        if state == .onboarding {
            bootstrapOnboardingIfNeeded()
        }
    }


    func handleEffectiveRouteChange(_ route: AppShellRoute) {
        if route == .welcome {
            logWelcomeScreenAnalytics()
        }
        logAppShellRouteDecision(selectedRoute: route)
    }

    // MARK: - Public entry analytics

    func logAppShellRouteDecision(selectedRoute: AppShellRoute) {
        let suppressAutomaticPublicEntryResume =
            container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
        let base = container.resolveAppShellRoute(
            authState: authManager.authState,
            rootState: rootModel.state,
            isOnboardingModelReady: onboardingModel != nil,
            awaitingCloudSync: awaitingCloudSync,
            pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
            publicEntryDestination: publicEntryDestination
        )
        AppShellRoutingLogger.logDecision(
            authState: authManager.authState,
            rootState: rootModel.state,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            localProfileAwaitingSignIn: container.profileBootstrapService.localProfileAwaitingSignIn(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            suppressAutomaticPublicEntryResume: suppressAutomaticPublicEntryResume,
            publicEntryDestination: publicEntryDestination,
            isOnboardingModelReady: onboardingModel != nil,
            baseRoute: base,
            selectedRoute: selectedRoute,
            trigger: "auth_gate_effective_route"
        )
    }

    func publicEntryAnalyticsProperties(
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil,
        reason: String? = nil
    ) -> PublicEntryAnalyticsProperties {
        PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            profileResolutionResult: profileResolutionResult ?? lastExistingUserResolutionResult,
            reason: reason
        )
    }

    func logWelcomeScreenAnalytics() {
        let base = publicEntryAnalyticsProperties()
        if let pending = container.publicEntrySessionStore.consumePendingEntrySource() {
            var properties = base
            properties.entrySource = pending.rawValue
            logPublicEntry(.welcomeViewed, properties: properties)
            if pending == .logout {
                logPublicEntry(.logoutCompletedPublicEntryShown, properties: properties)
            }
            return
        }

        guard !didLogColdStartWelcome else {
            logPublicEntry(.welcomeViewed, properties: base)
            return
        }

        didLogColdStartWelcome = true
        var properties = base
        properties.entrySource = PublicEntryEntrySource.freshInstall.rawValue
        logPublicEntry(.welcomeViewed, properties: properties)
    }

    func logPublicEntry(
        _ event: PublicEntryAnalyticsEvent,
        properties: PublicEntryAnalyticsProperties
    ) {
        container.publicEntryAnalyticsLogger.log(event, properties: properties)
    }

    // MARK: - Existing user sign-in analytics

    func logExistingUserSignIn(
        _ event: PublicEntryAnalyticsEvent,
        reason: ExistingUserSignInFailureKind? = nil,
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil
    ) {
        let properties = publicEntryAnalyticsProperties(
            profileResolutionResult: profileResolutionResult,
            reason: reason?.analyticsReason
        )
        container.publicEntryAnalyticsLogger.log(event, properties: properties)
    }

    func completeExistingUserSignInSuccessIfNeeded() {
        guard existingUserSignInSessionActive else { return }
        logExistingUserSignIn(
            .existingSignInSucceeded,
            profileResolutionResult: lastExistingUserResolutionResult
        )
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
        pendingExistingUserSignIn = false
    }

    func completeExistingUserSignInNoProfileIfNeeded() {
        guard existingUserSignInSessionActive else { return }
        logExistingUserSignIn(
            .existingSignInNoProfileFound,
            profileResolutionResult: .noProfileFound
        )
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
    }

    func completeExistingUserSignInFailure(_ kind: ExistingUserSignInFailureKind) {
        logExistingUserSignIn(.existingSignInFailed, reason: kind)
        existingUserSignInSessionActive = false
        pendingExistingUserSignIn = false
        existingUserSignInError = kind
        publicEntryDestination = .existingUserSignIn

        if AppRouteResolver.isSignedIn(authManager.authState) {
            suppressSignOutEntrySourceAnnotation = true
            prepareAuthenticatedSignOut(source: "existing_user_sign_in_failure")
            authManager.signOut()
        }
    }

    func didSignInAttemptFail(from previous: AuthState, to state: AuthState) -> Bool {
        switch (previous, state) {
        case (.signingIn, .signedOut), (.signingIn, .failed):
            return true
        default:
            return false
        }
    }

    func retryProfileLoad() {
        guard case .signedIn(let uid) = authManager.authState else { return }
        rootModel.retry(uid: uid)
    }
}
