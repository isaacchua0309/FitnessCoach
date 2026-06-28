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
    @State private var isResolvingProfileConflict = false
    @State private var awaitingCloudSync = false

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
                onboardingProfileConflictContent
            case .onboardingCloudCheckFailed:
                OnboardingCloudCheckFailedView {
                    retryOnboardingCompletionCloudCheck()
                }
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
            rootModel.presentOnboardingCloudProfileConflict()
        case .cloudCheckFailed, .cloudSyncFailed:
            rootModel.presentOnboardingCloudCheckFailed()
        }
    }

    private func finishOnboardingCompletionAfterSuccessfulSync() {
        if container.onboardingRoutingConfiguration.isV2Enabled {
            onboardingModel?.finalizeAfterSuccessfulSignIn()
        }
        clearOnboardingCompletionState()
        awaitingCloudSync = false
        rootModel.didCompleteOnboarding()
    }

    private func clearOnboardingCompletionState() {
        pendingSignInForOnboardingCompletion = false
        conflictCloudDocument = nil
        isResolvingProfileConflict = false
        onboardingModel = nil
    }

    @ViewBuilder
    private var onboardingProfileConflictContent: some View {
        if let cloudDocument = conflictCloudDocument,
           let localProfile = try? container.userProfileService.getCurrentProfile() {
            let summary = OnboardingProfileConflictSummaryBuilder.build(
                localProfile: localProfile,
                cloudDocument: cloudDocument
            )
            OnboardingProfileConflictView(
                summary: summary,
                isResolving: isResolvingProfileConflict,
                onRestoreExisting: { restoreExistingPlanAfterConflict() },
                onUseNewPlan: { useNewPlanAfterConflict() }
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
                _ = try container.userProfileService.replaceLocalProfile(with: cloudDocument)
                try container.dailyLogService.syncTodayTargetsFromProfile()
                container.onboardingCoachingContextStore.clear()
                if let uid = authManager.currentUID {
                    container.profileCloudSyncStore.markSynced(
                        uid: uid,
                        updatedAt: cloudDocument.updatedAt
                    )
                }
                if container.onboardingRoutingConfiguration.isV2Enabled {
                    onboardingModel?.finalizeAfterRestoredExistingPlan()
                }
                clearOnboardingCompletionState()
                rootModel.didCompleteOnboarding()
            } catch {
                isResolvingProfileConflict = false
                ProfileBootstrapDebugLogger.error(
                    "Failed to restore existing cloud profile after onboarding conflict",
                    fields: ["uid": uid],
                    underlying: error
                )
                rootModel.presentOnboardingCloudCheckFailed()
            }
        }
    }

    private func useNewPlanAfterConflict() {
        guard let uid = authManager.currentUID else { return }

        isResolvingProfileConflict = true

        Task { @MainActor in
            do {
                try await container.profileBootstrapCoordinatorService.syncOnboardingProfileToCloud(uid: uid)
                isResolvingProfileConflict = false
                finishOnboardingCompletionAfterSuccessfulSync()
            } catch {
                isResolvingProfileConflict = false
                ProfileBootstrapDebugLogger.error(
                    "onboarding_cloud_sync_failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                rootModel.presentOnboardingCloudCheckFailed()
            }
        }
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
                // Local profile remains usable; retry sync on a future sign-in.
                rootModel.didCompleteOnboarding()
            }
        }
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
        case .skip:
            break
        }
    }

    private func handleRootStateChange(_ state: RootViewState) {
        if state == .missingCloudProfile {
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
