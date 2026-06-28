//
//  AuthGateView.swift
//  Fitness Coach
//
//  FitPilot — Auth-gated shell with pre-auth onboarding.
//

import SwiftUI

struct AuthGateView: View {

    @ObservedObject private var authManager: AuthManager
    @StateObject private var rootModel: RootModel
    @State private var onboardingModel: OnboardingModel?
    @State private var signedInSessionID = UUID()
    @State private var pendingSignInForOnboardingCompletion = false
    @State private var pendingExistingUserSignIn = false
    @State private var existingUserSignInSessionActive = false
    @State private var existingUserSignInError: ExistingUserSignInFailureKind?
    @State private var returnToExistingUserSignInAfterSignOut = false
    @State private var publicEntryDestination: PublicEntryRoute = .welcome
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
    @State private var didLogColdStartWelcome = false
    @State private var suppressSignOutEntrySourceAnnotation = false
    @State private var lastExistingUserResolutionResult: ExistingUserSignInResolutionResult?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _authManager = ObservedObject(wrappedValue: container.authManager)
        _rootModel = StateObject(wrappedValue: container.makeRootModel())
    }

    var body: some View {
        Group {
            switch effectiveRoute {
            case .launchLoading, .onboardingStartInitializing, .onboardingInitializing:
                LaunchLoadingView()
                    .onAppear {
                        bootstrapOnboardingIfNeeded()
                    }
            case .signedInProfileLoading:
                if pendingExistingUserSignIn {
                    ExistingUserSignInResolvingView()
                } else {
                    LaunchLoadingView()
                        .onAppear {
                            bootstrapOnboardingIfNeeded()
                        }
                }
            case .welcome:
                PublicWelcomeView(
                    analyticsLogger: container.publicEntryAnalyticsLogger,
                    analyticsProperties: publicEntryAnalyticsProperties(),
                    onCreateMyPlan: beginOnboardingFromWelcome,
                    onSignIn: beginExistingUserSignInFromWelcome
                )
            case .existingUserSignIn:
                ExistingUserSignInView(
                    analyticsLogger: container.publicEntryAnalyticsLogger,
                    analyticsProperties: publicEntryAnalyticsProperties(),
                    localError: existingUserSignInError,
                    onBack: returnToWelcomeFromExistingUserSignIn,
                    onCreateMyPlan: beginOnboardingFromExistingUserSignIn,
                    onSignInRequested: signInAsExistingUser
                )
            case .onboardingStart:
                preAuthOnboardingContent
            case .noExistingProfileFound:
                NoExistingProfileFoundView(
                    analyticsLogger: container.publicEntryAnalyticsLogger,
                    analyticsProperties: publicEntryAnalyticsProperties(
                        profileResolutionResult: .noProfileFound
                    ),
                    onStartOnboarding: beginOnboardingAfterNoExistingPlan,
                    onUseAnotherAccount: useAnotherAccountAfterNoExistingPlan
                )
            case .onboardingCloudProfileConflict:
                profilePlanConflictContent
            case .onboardingCloudCheckFailed:
                OnboardingCloudCheckFailedView {
                    retryAccountMismatchOrOnboardingCloudCheck()
                }
            case .existingUserProfileLookupFailed:
                ExistingUserProfileLookupFailedView {
                    retryExistingUserProfileResolution()
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
        .environment(\.publicEntrySessionStore, container.publicEntrySessionStore)
        .task {
            authManager.startListening()
        }
        .onChange(of: effectiveRoute) { _, route in
            if route == .welcome {
                logWelcomeScreenAnalytics()
            }
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
        let suppressAutomaticPublicEntryResume =
            container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
        let hasLocalProfile = container.profileBootstrapService.hasLocalProfile()
        let base = container.resolveAppShellRoute(
            authState: authManager.authState,
            rootState: rootModel.state,
            isOnboardingModelReady: onboardingModel != nil,
            awaitingCloudSync: awaitingCloudSync,
            pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
            publicEntryDestination: publicEntryDestination
        )
        let selected = AuthGateRoutingPolicy.effectiveRoute(
            baseRoute: base,
            isSignedIn: AppRouteResolver.isSignedIn(authManager.authState),
            hasActiveOnboardingSession: onboardingModel != nil,
            suppressAutomaticPublicEntryResume: suppressAutomaticPublicEntryResume
        )
        AppShellRoutingLogger.logDecision(
            authState: authManager.authState,
            rootState: rootModel.state,
            hasLocalProfile: hasLocalProfile,
            localProfileAwaitingSignIn: container.profileBootstrapService.localProfileAwaitingSignIn(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            suppressAutomaticPublicEntryResume: suppressAutomaticPublicEntryResume,
            publicEntryDestination: publicEntryDestination,
            isOnboardingModelReady: onboardingModel != nil,
            baseRoute: base,
            selectedRoute: selected,
            trigger: "auth_gate_effective_route"
        )
        return selected
    }

    // MARK: - Public entry actions

    private func beginOnboardingFromWelcome() {
        startPreAuthOnboarding()
    }

    private func beginExistingUserSignInFromWelcome() {
        onboardingModel = nil
        existingUserSignInError = nil
        publicEntryDestination = .existingUserSignIn
    }

    private func returnToWelcomeFromExistingUserSignIn() {
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
        publicEntryDestination = .welcome
    }

    private func returnToWelcomeFromOnboarding() {
        onboardingModel = nil
        container.onboardingDraftStore.clearDraft()
        publicEntryDestination = .welcome
    }

    private func beginOnboardingFromExistingUserSignIn() {
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
        startPreAuthOnboarding()
    }

    private func startPreAuthOnboarding() {
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        container.publicEntrySessionStore.clearExplicitSignOut()
        publicEntryDestination = WelcomeOnboardingHandoffPolicy.createPlanDestination
        onboardingModel = nil
        rootModel.resolveLocalProfile()
        ensurePreAuthOnboardingModel()
    }

    private func signInAsExistingUser() {
        existingUserSignInError = nil
        pendingExistingUserSignIn = true
        existingUserSignInSessionActive = true
        logExistingUserSignIn(.existingSignInStarted)
        Task {
            await authManager.signInWithGoogle()
        }
    }

    private func beginOnboardingAfterNoExistingPlan() {
        onboardingModel = nil
        pendingExistingUserSignIn = false
        existingUserSignInSessionActive = false
        rootModel.continueFromMissingCloudProfile()
        ensureOnboardingModel()
    }

    private func useAnotherAccountAfterNoExistingPlan() {
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
        if AppRouteResolver.isSignedIn(authManager.authState) {
            OnboardingView(model: model)
        } else {
            OnboardingView(model: model, onExitToWelcome: returnToWelcomeFromOnboarding)
        }
    }

    private func preparePreAuthOnboardingIfNeeded() {
        guard !AppRouteResolver.isSignedIn(authManager.authState) else { return }
        rootModel.resolveLocalProfile()
        if publicEntryDestination == WelcomeOnboardingHandoffPolicy.createPlanDestination {
            ensurePreAuthOnboardingModel()
        } else {
            ensureOnboardingModel()
        }
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
                .tint(OnboardingTheme.ctaBackground)
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
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
        container.publicEntrySessionStore.markUserInitiatedLogout()
        prepareAuthenticatedSignOut(source: "account_profile_mismatch")
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
    /// Without this, `.onboardingInitializing` shows only
    /// `LaunchLoadingView` and never reach the views whose `onAppear` used to create the model.
    private func bootstrapOnboardingIfNeeded() {
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

    private func ensurePreAuthOnboardingModel() {
        guard onboardingModel == nil else { return }
        onboardingModel = container.makeOnboardingModel(
            entry: WelcomeOnboardingHandoffPolicy.preAuthEntry,
            onCompletion: { handleOnboardingCompletionRequest() }
        )
    }

    private func ensureOnboardingModel() {
        guard onboardingModel == nil else { return }
        let entry = NoExistingProfileFoundPolicy.onboardingEntry(
            isSignedIn: AppRouteResolver.isSignedIn(authManager.authState)
        )
        onboardingModel = container.makeOnboardingModel(entry: entry) {
            handleOnboardingCompletionRequest()
        }
    }

    private func handleOnboardingCompletionRequest() {
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
        onboardingModel?.finalizeAfterSuccessfulSignIn()
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

    private func finishProfileConflictAfterUpload() {
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

    private func retryOnboardingCompletionCloudCheck() {
        guard let uid = authManager.currentUID else { return }
        Task { await resolveOnboardingCompletionAfterSignIn(uid: uid) }
    }

    private func finishOnboardingLocally() {
        onboardingModel?.finalizeAfterSuccessfulSignIn()
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

    private func handleAuthStateChange(from previous: AuthState, to state: AuthState) {
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

    private func handleSignedOutTransition(
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
            onboardingModel?.handleSignInCompletionFailure(
                message: onboardingSignInFailureMessage(from: state),
                wasCancelled: wasCancelled
            )
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

    private func prepareAuthenticatedSignOut(source: String) {
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

    private func reconcileSignedInProfile(uid: String, isFreshSignIn: Bool) {
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
    private func runExistingUserSignInResolution(uid: String, isFreshSignIn: Bool) async {
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

    private func applyExistingUserSignInResolution(
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

    private func retryExistingUserProfileResolution() {
        guard let uid = authManager.currentUID else { return }
        existingUserSignInSessionActive = true
        existingUserSignInError = nil
        Task { await runExistingUserSignInResolution(uid: uid, isFreshSignIn: false) }
    }

    private func clearStaleOnboardingDraftIfSafe() {
        guard OnboardingDraftPolicy.shouldClearStaleDraftAfterExistingUserRestore(
            hasPersistedDraft: container.onboardingDraftStore.hasDraft
        ) else {
            return
        }
        container.onboardingDraftStore.clearDraft()
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

    private func performOwnershipCloudLookup(uid: String, isFreshSignIn: Bool) {
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

    private func handleRootStateChange(_ state: RootViewState) {
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

    // MARK: - Public entry analytics

    private func publicEntryAnalyticsProperties(
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil,
        reason: String? = nil
    ) -> PublicEntryAnalyticsProperties {
        PublicEntryAnalyticsContextBuilder.properties(
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            profileResolutionResult: profileResolutionResult ?? lastExistingUserResolutionResult,
            reason: reason
        )
    }

    private func logWelcomeScreenAnalytics() {
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

    private func logPublicEntry(
        _ event: PublicEntryAnalyticsEvent,
        properties: PublicEntryAnalyticsProperties
    ) {
        container.publicEntryAnalyticsLogger.log(event, properties: properties)
    }

    // MARK: - Existing user sign-in analytics

    private func logExistingUserSignIn(
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

    private func completeExistingUserSignInSuccessIfNeeded() {
        guard existingUserSignInSessionActive else { return }
        logExistingUserSignIn(
            .existingSignInSucceeded,
            profileResolutionResult: lastExistingUserResolutionResult
        )
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
        pendingExistingUserSignIn = false
    }

    private func completeExistingUserSignInNoProfileIfNeeded() {
        guard existingUserSignInSessionActive else { return }
        logExistingUserSignIn(
            .existingSignInNoProfileFound,
            profileResolutionResult: .noProfileFound
        )
        existingUserSignInSessionActive = false
        existingUserSignInError = nil
    }

    private func completeExistingUserSignInFailure(_ kind: ExistingUserSignInFailureKind) {
        logExistingUserSignIn(.existingSignInFailed, reason: kind)
        existingUserSignInSessionActive = false
        pendingExistingUserSignIn = false
        existingUserSignInError = kind
        publicEntryDestination = .existingUserSignIn

        if AppRouteResolver.isSignedIn(authManager.authState) {
            suppressSignOutEntrySourceAnnotation = true
            Task {
                await authManager.signOut()
            }
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
        .formaThemePreview()
}
