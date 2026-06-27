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
            isOnboardingModelReady: onboardingModel != nil
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
            syncOnboardingToCloudAndFinish()
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

    private func completeOnboardingLocallyWithoutSignIn() {
        onboardingModel = nil
        rootModel.resolveLocalProfile()
        rootModel.didCompleteOnboarding()
    }

    /// Signed-in onboarding completion: upload locally committed profile then enter main.
    private func syncOnboardingToCloudAndFinish() {
        guard let uid = authManager.currentUID else {
            finishOnboardingLocally()
            return
        }

        Task { @MainActor in
            await syncOnboardingProfileToCloud(uid: uid)
            if container.onboardingRoutingConfiguration.isV2Enabled {
                onboardingModel?.finalizeAfterSuccessfulSignIn()
            }
            onboardingModel = nil
            rootModel.didCompleteOnboarding()
        }
    }

    private func finishOnboardingLocally() {
        if container.onboardingRoutingConfiguration.isV2Enabled {
            onboardingModel?.finalizeAfterSuccessfulSignIn()
        }
        onboardingModel = nil
        rootModel.didCompleteOnboarding()
    }

    private func syncOnboardingProfileToCloud(uid: String) async {
        do {
            try await container.profileBootstrapService.syncOnboardingProfileToCloud(uid: uid)
        } catch {
            ProfileBootstrapDebugLogger.error(
                "Cloud profile sync failed after onboarding",
                fields: ["uid": uid],
                underlying: error
            )
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
        if container.profileBootstrapService.hasLocalProfile() {
            rootModel.didCompleteOnboarding()
            return
        }

        let shouldLoadCloudProfile = AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
            isFreshSignIn: isFreshSignIn,
            rootState: rootModel.state,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile()
        )

        guard shouldLoadCloudProfile else { return }

        if rootModel.state == .onboarding {
            onboardingModel = nil
        }
        rootModel.load(uid: uid)
    }

    private func handleRootStateChange(_ state: RootViewState) {
        if state == .missingCloudProfile {
            onboardingModel = nil
        }

        if state == .onboarding {
            bootstrapOnboardingIfNeeded()
        }

        guard pendingSignInForOnboardingCompletion else { return }
        guard AppRouteResolver.isSignedIn(authManager.authState) else { return }
        guard state == .main else { return }

        pendingSignInForOnboardingCompletion = false
        syncOnboardingToCloudAndFinish()
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
