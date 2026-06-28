//
//  AuthGateView.swift
//  Fitness Coach
//
//  FitPilot — Auth-gated shell with optional v2 pre-auth onboarding.
//

import SwiftUI

struct AuthGateView: View {

    @ObservedObject private var authManager: AuthManager
    @StateObject private var rootModel: RootModel
    @State private var onboardingModel: OnboardingModel?
    @State private var signedInSessionID = UUID()
    @State private var pendingSignInForOnboardingCompletion = false
    @State private var pendingSignInForValueFirstHandoff = false
    @State private var preAuthRouteOverride: AppShellRoute?
    @State private var conflictCloudDocument: CloudUserProfileDocument?
    @State private var profileConflictContext: ProfileConflictResolutionContext = .accountOrOwnershipReconcile
    @State private var isResolvingProfileConflict = false
    @State private var showUseDevicePlanOverwriteConfirmation = false
    @State private var isResolvingAccountMismatch = false
    @State private var showUseDeviceProfileConfirmation = false
    @State private var retryFromAccountMismatch = false
    @State private var awaitingCloudSync = false
    @State private var pendingUploadFailureContext: CloudProfileUploadFailureContext?
    @State private var isRetryingCloudUpload = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _authManager = ObservedObject(wrappedValue: container.authManager)
        _rootModel = StateObject(wrappedValue: container.makeRootModel())
    }

    var body: some View {
        Group {
            switch effectiveRoute {
            case .launchLoading, .localOnboardingInitializing, .onboardingInitializing, .signedInProfileLoading:
                LaunchLoadingView()
                    .onAppear {
                        bootstrapOnboardingIfNeeded()
                    }
            case .signIn:
                SignInView()
            case .localOnboarding:
                preAuthOnboardingContent
            case .localMain:
                MainTabView(container: container)
            case .missingCloudProfile:
                MissingCloudProfileView {
                    onboardingModel = nil
                    rootModel.continueFromMissingCloudProfile()
                }
            case .onboardingCloudProfileConflict:
                profilePlanConflictContent
            case .onboardingCloudCheckFailed:
                OnboardingCloudCheckFailedView {
                    retryAccountMismatchOrOnboardingCloudCheck()
                }
            case .cloudProfileUploadFailed:
                CloudProfileUploadFailedView(
                    isRetrying: isRetryingCloudUpload,
                    onRetry: retryCloudProfileUpload,
                    onContinue: continueAfterCloudUploadFailure
                )
            case .accountProfileMismatch:
                accountProfileMismatchContent
            case .onboarding:
                signedInOnboardingContent
                    .id(signedInSessionID)
            case .main:
                MainTabView(container: container)
                    .id(signedInSessionID)
            case .profileError(let message):
                profileErrorView(message: message)
            }
        }
        .environmentObject(authManager)
        .task {
            authManager.startListening()
        }
        .onChange(of: authManager.authState, initial: true) { previous, state in
            handleAuthStateChange(from: previous, to: state)
        }
        .onChange(of: rootModel.state) { _, state in
            handleRootStateChange(state)
        }
        .onChange(of: container.cloudUploadFailureNotifier.pendingContext) { _, context in
            guard let context else { return }
            presentCloudProfileUploadFailure(context: context)
        }
        .alert(
            FormaProductCopy.Onboarding.V2.AccountProfileMismatch.useDeviceProfileConfirmTitle,
            isPresented: $showUseDeviceProfileConfirmation
        ) {
            Button(
                FormaProductCopy.Onboarding.V2.AccountProfileMismatch.useDeviceProfileConfirmAction,
                action: confirmUseDeviceProfileAfterPrompt
            )
            Button(
                FormaProductCopy.Onboarding.V2.AccountProfileMismatch.cancelAction,
                role: .cancel
            ) {}
        } message: {
            Text(FormaProductCopy.Onboarding.V2.AccountProfileMismatch.useDeviceProfileConfirmBody)
        }
        .alert(
            FormaProductCopy.Onboarding.V2.ProfileConflict.useDevicePlanConfirmTitle,
            isPresented: $showUseDevicePlanOverwriteConfirmation
        ) {
            Button(
                FormaProductCopy.Onboarding.V2.ProfileConflict.useDevicePlanConfirmAction,
                action: confirmUseDevicePlanAfterConflict
            )
            Button(
                FormaProductCopy.Onboarding.V2.ProfileConflict.cancelAction,
                role: .cancel
            ) {}
        } message: {
            Text(FormaProductCopy.Onboarding.V2.ProfileConflict.useDevicePlanConfirmBody)
        }
    }

    // MARK: - Routing

    private var effectiveRoute: AppShellRoute {
        if let preAuthRouteOverride,
           !AppRouteResolver.isSignedIn(authManager.authState) {
            return preAuthRouteOverride
        }

        let base = container.resolveAppShellRoute(
            authState: authManager.authState,
            rootState: rootModel.state,
            isOnboardingModelReady: onboardingModel != nil,
            awaitingCloudSync: awaitingCloudSync
        )
        return AuthGateRoutingPolicy.effectiveRoute(
            baseRoute: base,
            isV2Enabled: container.onboardingRoutingConfiguration.isV2Enabled,
            isSignedIn: AppRouteResolver.isSignedIn(authManager.authState),
            hasActiveOnboardingSession: onboardingModel != nil
        )
    }

    // MARK: - Pre-auth onboarding (v2)

    @ViewBuilder
    private var preAuthOnboardingContent: some View {
        Group {
            if let onboardingModel {
                onboardingShell(for: onboardingModel)
            } else {
                LaunchLoadingView()
            }
        }
        .onAppear {
            preparePreAuthOnboardingIfNeeded()
        }
    }

    @ViewBuilder
    private func onboardingShell(for model: OnboardingModel) -> some View {
        if container.onboardingRoutingConfiguration.isV2Enabled {
            if showsSignInFromLanding(for: model) {
                OnboardingView(model: model, onExistingAccount: showExistingAccountSignIn)
            } else {
                OnboardingView(model: model)
            }
        } else {
            OnboardingView(model: model)
        }
    }

    private func showsSignInFromLanding(for model: OnboardingModel) -> Bool {
        switch model.flowScope {
        case .v2Full, .v2ValueFirstTeaser:
            return true
        case .legacy, .v2PostAuth:
            return false
        }
    }

    private func showExistingAccountSignIn() {
        if AuthGateRoutingPolicy.shouldSignOutBeforeExistingAccountSignIn(
            isSignedIn: AppRouteResolver.isSignedIn(authManager.authState)
        ) {
            authManager.signOut()
        }
        Task {
            await authManager.signInWithGoogle()
        }
    }

    private func preparePreAuthOnboardingIfNeeded() {
        guard !AppRouteResolver.isSignedIn(authManager.authState) else { return }
        rootModel.resolveLocalProfile()
        ensureOnboardingModel()
    }

    // MARK: - Signed-in flow

    @ViewBuilder
    private var signedInOnboardingContent: some View {
        Group {
            if let onboardingModel {
                onboardingShell(for: onboardingModel)
            } else {
                LaunchLoadingView()
            }
        }
        .onAppear {
            ensureOnboardingModel()
        }
    }

    private func profileErrorView(message: String) -> some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.warning)
                        .accessibilityHidden(true)

                    Text(FormaProductCopy.Onboarding.V2.BootstrapError.title)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                Button(FormaProductCopy.Onboarding.V2.BootstrapError.retryCTA) {
                    retryProfileLoad()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var accountProfileMismatchContent: some View {
        AccountProfileMismatchView(
            isResolving: isResolvingAccountMismatch,
            onRestoreGooglePlan: restoreGoogleAccountPlanAfterMismatch,
            onUseDeviceProfile: beginUseDeviceProfileAfterMismatch,
            onSignOut: signOutFromAccountMismatch
        )
    }

    private func restoreGoogleAccountPlanAfterMismatch() {
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

    private func beginUseDeviceProfileAfterMismatch() {
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

    private func confirmUseDeviceProfileAfterPrompt() {
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

    private func signOutFromAccountMismatch() {
        authManager.signOut()
    }

    private func retryAccountMismatchOrOnboardingCloudCheck() {
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
    /// Without this, `.onboardingInitializing` / `.localOnboardingInitializing` show only
    /// `LaunchLoadingView` and never reach the views whose `onAppear` used to create the model.
    private func bootstrapOnboardingIfNeeded() {
        let signedIn = AppRouteResolver.isSignedIn(authManager.authState)
        let config = container.onboardingRoutingConfiguration

        let hasLocalProfile = container.profileBootstrapService.hasLocalProfile()
        let needsPreAuthOnboarding = !signedIn
            && config.usesPreAuthShellRouting
            && !(config.allowsLocalOnlyContinuation && hasLocalProfile)

        let needsSignedInOnboarding = signedIn && rootModel.state == .onboarding

        if needsPreAuthOnboarding {
            rootModel.resolveLocalProfile()
        }

        if needsPreAuthOnboarding || needsSignedInOnboarding {
            ensureOnboardingModel()
        }
    }

    private func ensureOnboardingModel() {
        guard onboardingModel == nil else { return }
        let entry: OnboardingAnalyticsEntry = AppRouteResolver.isSignedIn(authManager.authState)
            ? .postAuth
            : .preAuth
        onboardingModel = container.makeOnboardingModel(entry: entry) {
            handleOnboardingCompletionRequest()
        }
    }

    private func handleOnboardingCompletionRequest() {
        if onboardingModel?.pendingCompletionIntent == .localOnly {
            completeOnboardingLocallyWithoutSignIn()
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

        if onboardingModel?.expectsValueFirstSignInHandoff == true {
            pendingSignInForValueFirstHandoff = true
            Task {
                await authManager.signInWithGoogle()
            }
            return
        }

        guard container.onboardingRoutingConfiguration.isV2Enabled else {
            ProfileBootstrapDebugLogger.warn(
                "Onboarding completion without signed-in session in legacy mode",
                fields: [:]
            )
            onboardingModel = nil
            rootModel.didCompleteOnboarding()
            return
        }

        pendingSignInForOnboardingCompletion = true
        onboardingModel?.beginSignInForCompletion()
        Task {
            await authManager.signInWithGoogle()
        }
    }

    /// Signed-in onboarding completion: probe cloud, then sync or show conflict UI.
    private func resolveOnboardingCompletionAfterSignIn(uid: String) async {
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

    private func presentCloudProfileUploadFailure(context: CloudProfileUploadFailureContext) {
        pendingUploadFailureContext = context
        container.profileCloudSyncStore.clear()
        container.cloudUploadFailureNotifier.clear()
        awaitingCloudSync = false
        rootModel.presentCloudProfileUploadFailed()
    }

    private func finishOnboardingCompletionAfterSuccessfulSync() {
        if container.onboardingRoutingConfiguration.isV2Enabled {
            onboardingModel?.finalizeAfterSuccessfulSignIn()
        }
        clearOnboardingCompletionState()
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    private func clearProfileConflictState() {
        conflictCloudDocument = nil
        isResolvingProfileConflict = false
        profileConflictContext = .accountOrOwnershipReconcile
    }

    private func clearOnboardingCompletionState() {
        pendingSignInForOnboardingCompletion = false
        clearProfileConflictState()
        onboardingModel = nil
    }

    @ViewBuilder
    private var profilePlanConflictContent: some View {
        if let cloudDocument = conflictCloudDocument,
           let localProfile = try? container.userProfileService.getCurrentProfile() {
            let summary = ProfilePlanConflictSummaryBuilder.build(
                localProfile: localProfile,
                cloudDocument: cloudDocument
            )
            ProfilePlanConflictView(
                summary: summary,
                isResolving: isResolvingProfileConflict,
                onRestoreExisting: restoreExistingPlanAfterConflict,
                onUseDevicePlan: beginUseDevicePlanAfterConflict
            )
        } else {
            LaunchLoadingView()
        }
    }

    private func restoreExistingPlanAfterConflict() {
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

    private func beginUseDevicePlanAfterConflict() {
        showUseDevicePlanOverwriteConfirmation = true
    }

    private func confirmUseDevicePlanAfterConflict() {
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

    private func finishProfileConflictAfterRestore() {
        switch profileConflictContext {
        case .onboardingCompletion:
            if container.onboardingRoutingConfiguration.isV2Enabled {
                onboardingModel?.finalizeAfterRestoredExistingPlan()
            }
            clearOnboardingCompletionState()
        case .accountOrOwnershipReconcile:
            clearProfileConflictState()
        }
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    private func finishProfileConflictAfterUpload() {
        switch profileConflictContext {
        case .onboardingCompletion:
            if container.onboardingRoutingConfiguration.isV2Enabled {
                onboardingModel?.finalizeAfterSuccessfulSignIn()
            }
            clearOnboardingCompletionState()
        case .accountOrOwnershipReconcile:
            clearProfileConflictState()
        }
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    private func retryOnboardingCompletionCloudCheck() {
        guard let uid = authManager.currentUID else { return }
        Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
    }

    private func completeOnboardingLocallyWithoutSignIn() {
        onboardingModel = nil
        rootModel.resolveLocalProfile()
        rootModel.didCompleteOnboarding()
    }

    private func finishOnboardingLocally() {
        if container.onboardingRoutingConfiguration.isV2Enabled {
            onboardingModel?.finalizeAfterSuccessfulSignIn()
        }
        onboardingModel = nil
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    private func syncUnsyncedLocalProfile(uid: String) {
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

    private func retryCloudProfileUpload() {
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

    private func finishAfterSuccessfulCloudUpload(context: CloudProfileUploadFailureContext) {
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

    private func continueAfterCloudUploadFailure() {
        let context = pendingUploadFailureContext
        container.profileCloudSyncStore.clear()
        pendingUploadFailureContext = nil
        container.cloudUploadFailureNotifier.clear()

        switch context {
        case .onboardingCompletion:
            if container.onboardingRoutingConfiguration.isV2Enabled {
                onboardingModel?.finalizeAfterSuccessfulSignIn()
            }
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

    private func handleAuthStateChange(from previous: AuthState, to state: AuthState) {
        let wasSignedIn = AppRouteResolver.isSignedIn(previous)
        let isSignedInNow = AppRouteResolver.isSignedIn(state)

        if isSignedInNow {
            preAuthRouteOverride = nil
            let isFreshSignIn = AppRouteResolver.shouldRotateSignedInSession(
                wasSignedIn: wasSignedIn,
                isSignedIn: isSignedInNow
            )
            if isFreshSignIn {
                if pendingSignInForValueFirstHandoff {
                    pendingSignInForValueFirstHandoff = false
                    onboardingModel = nil
                }
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

    private func handleSignedOutTransition(
        from previous: AuthState,
        to state: AuthState,
        wasSignedIn: Bool
    ) {
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
            onboardingModel?.handleSignInCompletionFailure(
                message: onboardingSignInFailureMessage(from: state),
                wasCancelled: wasCancelled
            )
        }

        if pendingSignInForValueFirstHandoff, didSignInAttemptFail(from: previous, to: state) {
            pendingSignInForValueFirstHandoff = false
            onboardingModel?.clearError()
        }

        if wasSignedIn {
            preAuthRouteOverride = nil
            pendingSignInForOnboardingCompletion = false
            conflictCloudDocument = nil
            isResolvingProfileConflict = false
        }

        if AppRouteResolver.shouldClearOnboardingModel(
            wasSignedIn: wasSignedIn,
            isSignedIn: false,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft
        ) {
            onboardingModel = nil
        }

        rootModel.resolveLocalProfile()

        if container.onboardingRoutingConfiguration.usesPreAuthShellRouting,
           !container.profileBootstrapService.hasLocalProfile(),
           onboardingModel == nil,
           container.onboardingDraftStore.hasDraft {
            ensureOnboardingModel()
        }
    }

    private func reconcileSignedInProfile(uid: String, isFreshSignIn: Bool) {
        let decision = container.profileBootstrapCoordinatorService.reconcileDecision(
            uid: uid,
            pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
            isFreshSignIn: isFreshSignIn,
            rootState: rootModel.state
        )
        applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
    }

    private func applyReconcileDecision(
        _ decision: SignedInProfileReconcileDecision,
        uid: String,
        isFreshSignIn: Bool
    ) {
        switch decision {
        case .resolveOnboardingCompletion(let uid):
            Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
        case .routeToMain:
            awaitingCloudSync = false
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
            rootModel.presentMissingCloudProfile()
        case .skip:
            break
        }
    }

    private func performOwnershipCloudLookup(uid: String, isFreshSignIn: Bool) {
        Task { @MainActor in
            let cloudResult = await container.profileBootstrapCoordinatorService.ownershipCloudLookup(
                uid: uid,
                context: .ownershipResolution
            )
            let decision = container.profileBootstrapCoordinatorService.reconcileDecision(
                uid: uid,
                pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
                isFreshSignIn: isFreshSignIn,
                rootState: rootModel.state,
                cloudResult: cloudResult
            )
            applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
        }
    }

    private func presentProfileConflictAfterLookup(uid: String) {
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
                rootModel.presentOnboardingCloudCheckFailed()
            }
        }
    }

    private func handleRootStateChange(_ state: RootViewState) {
        if state == .missingCloudProfile {
            onboardingModel = nil
        }

        if state == .accountProfileMismatch {
            onboardingModel = nil
        }

        if state == .onboarding {
            bootstrapOnboardingIfNeeded()
        }
    }

    private func didSignInAttemptFail(from previous: AuthState, to state: AuthState) -> Bool {
        switch (previous, state) {
        case (.signingIn, .signedOut), (.signingIn, .failed):
            return true
        default:
            return false
        }
    }

    private func retryProfileLoad() {
        guard case .signedIn(let uid) = authManager.authState else { return }
        rootModel.retry(uid: uid)
    }

    private func onboardingSignInFailureMessage(from state: AuthState) -> String {
        if case .failed = state,
           let presentation = AuthSignInPresentationPolicy.failurePresentation(authState: state) {
            return presentation.message
        }
        return FormaProductCopy.Onboarding.V2.SavePlan.signInRetryMessage
    }
}

#Preview {
    AuthGateView(container: try! AppContainer(inMemory: true))
}
