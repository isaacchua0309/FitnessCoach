//
//  PublicEntryFlowCoordinator.swift
//  Fitness Coach
//
//  Welcome / returning-member sign-in entry flow for the auth gate shell.
//

import Foundation

@MainActor
protocol PublicEntryFlowCoordinatorDelegate: AnyObject {
    var publicEntryDestination: PublicEntryRoute { get set }
    var pendingExistingUserSignIn: Bool { get set }
    var existingUserSignInSessionActive: Bool { get set }
    var existingUserSignInError: ExistingUserSignInFailureKind? { get set }
    var returnToExistingUserSignInAfterSignOut: Bool { get set }
    var didLogColdStartWelcome: Bool { get set }
    var suppressSignOutEntrySourceAnnotation: Bool { get set }
    var lastExistingUserResolutionResult: ExistingUserSignInResolutionResult? { get set }

    func clearOnboardingModel()
    func clearOnboardingDraft()
    func resolveLocalProfile()
    func startPreAuthOnboardingModel()
    func bootstrapOnboardingModel()
    func continueFromMissingCloudProfile()
    func prepareAuthenticatedSignOut(source: String)
    func signOutFromAuthManager()
    func clearTransientAuthState()
    func resetRootForSignedOutSession()
}

@MainActor
final class PublicEntryFlowCoordinator {

    private weak var delegate: PublicEntryFlowCoordinatorDelegate?
    private let container: AppContainer
    private let authManager: AuthManager

    init(container: AppContainer, authManager: AuthManager) {
        self.container = container
        self.authManager = authManager
    }

    func configure(delegate: PublicEntryFlowCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Public entry actions

    func beginOnboardingFromWelcome() {
        startPreAuthOnboarding()
    }

    func beginExistingUserSignInFromWelcome() {
        guard let delegate else { return }
        delegate.clearOnboardingModel()
        delegate.existingUserSignInError = nil
        delegate.publicEntryDestination = .existingUserSignIn
    }

    func returnToWelcomeFromExistingUserSignIn() {
        guard let delegate else { return }
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
        delegate.existingUserSignInError = nil
        delegate.publicEntryDestination = .welcome
    }

    func returnToWelcomeFromOnboarding() {
        guard let delegate else { return }
        // Order is load-bearing:
        // 1) Suppress automatic draft / awaiting-sign-in welcome bypass.
        // 2) Set destination to welcome while the session still exists so
        //    AuthGateRoutingPolicy cannot prefer onboarding over welcome.
        // 3) Clear draft, then clear the model last so we never land on
        //    `.onboardingStartInitializing` (LaunchLoadingView.onAppear → bootstrap)
        //    with a residual draft that restores a mid-flow step.
        container.publicEntrySessionStore.markExplicitSignOut()
        delegate.publicEntryDestination = .welcome
        delegate.clearOnboardingDraft()
        delegate.clearOnboardingModel()
    }

    func beginOnboardingFromExistingUserSignIn() {
        guard let delegate else { return }
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
        delegate.existingUserSignInError = nil
        startPreAuthOnboarding()
    }

    func startPreAuthOnboarding() {
        guard let delegate else { return }
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
        container.publicEntrySessionStore.clearExplicitSignOut()
        delegate.publicEntryDestination = WelcomeOnboardingHandoffPolicy.createPlanDestination
        delegate.clearOnboardingModel()
        delegate.resolveLocalProfile()
        delegate.startPreAuthOnboardingModel()
    }

    func signInAsExistingUser() {
        guard let delegate else { return }
        delegate.existingUserSignInError = nil
        delegate.pendingExistingUserSignIn = true
        delegate.existingUserSignInSessionActive = true
        logExistingUserSignIn(.existingSignInStarted)
        Task {
            let outcome = await authManager.signInWithGoogle()
            applyExistingUserGoogleSignInOutcome(outcome)
        }
    }

    func beginOnboardingAfterNoExistingPlan() {
        guard let delegate else { return }
        delegate.clearOnboardingModel()
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
        delegate.continueFromMissingCloudProfile()
        delegate.bootstrapOnboardingModel()
    }

    func useAnotherAccountAfterNoExistingPlan() {
        guard let delegate else { return }
        delegate.returnToExistingUserSignInAfterSignOut = true
        delegate.existingUserSignInSessionActive = false
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInError = nil
        delegate.clearOnboardingModel()
        delegate.suppressSignOutEntrySourceAnnotation = true
        delegate.prepareAuthenticatedSignOut(source: "no_existing_profile_use_another_account")
        delegate.signOutFromAuthManager()
    }

    func applyExistingUserGoogleSignInOutcome(_ outcome: GoogleSignInAttemptOutcome) {
        guard let delegate else { return }
        switch outcome {
        case .success:
            return
        case .cancelled:
            guard delegate.existingUserSignInSessionActive || delegate.pendingExistingUserSignIn else { return }
            delegate.existingUserSignInSessionActive = false
            delegate.pendingExistingUserSignIn = false
            delegate.existingUserSignInError = nil
            delegate.clearTransientAuthState()
        case .failed:
            guard delegate.existingUserSignInSessionActive || delegate.pendingExistingUserSignIn else { return }
            let failureKind: ExistingUserSignInFailureKind
            if case .failed(let message) = authManager.authState,
               message == AuthSignInUserMessage.signInFailureMessage {
                failureKind = .networkFailed
            } else {
                failureKind = .authFailed
            }
            completeExistingUserSignInFailure(failureKind)
            delegate.clearTransientAuthState()
        }
    }

    // MARK: - Auth transition helpers

    func resetPublicEntryDestinationOnSignIn() {
        delegate?.publicEntryDestination = .welcome
    }

    func handleExistingUserSignInAttemptIfNeeded(from previous: AuthState, to state: AuthState) {
        guard let delegate else { return }
        guard delegate.pendingExistingUserSignIn || delegate.existingUserSignInSessionActive,
              didSignInAttemptFail(from: previous, to: state) else {
            return
        }

        if case .signedOut = state {
            delegate.existingUserSignInSessionActive = false
            delegate.pendingExistingUserSignIn = false
            delegate.existingUserSignInError = nil
            delegate.clearTransientAuthState()
        } else if let failureKind = ExistingUserSignInPolicy.failureKind(from: previous, to: state) {
            completeExistingUserSignInFailure(failureKind)
            delegate.clearTransientAuthState()
        }
    }

    func resetPublicEntryFlagsForAccountDeletion() {
        guard let delegate else { return }
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
    }

    func applyPublicEntryDestinationAfterSignOut() {
        guard let delegate else { return }
        delegate.publicEntryDestination = AuthLogoutPolicy.publicEntryDestinationAfterSignOut(
            returnToExistingUserSignIn: delegate.returnToExistingUserSignInAfterSignOut,
            hasExistingUserSignInError: delegate.existingUserSignInError != nil
        )
    }

    func applyWasSignedInPublicEntryReset() {
        guard let delegate else { return }
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
        applyPublicEntryDestinationAfterSignOut()
        if delegate.returnToExistingUserSignInAfterSignOut {
            delegate.returnToExistingUserSignInAfterSignOut = false
            delegate.existingUserSignInError = nil
        }
    }

    func applyColdLaunchPublicEntryDestinationIfNeeded() -> Bool {
        guard let delegate else { return false }
        guard let resumedDestination = AuthLogoutPolicy.coldLaunchPublicEntryDestination(
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            suppressAutomaticPublicEntryResume:
                container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
        ) else {
            return false
        }
        delegate.publicEntryDestination = resumedDestination
        delegate.resolveLocalProfile()
        return true
    }

    func applyExplicitSignOutWelcomeIfNeeded() {
        guard let delegate else { return }
        guard container.publicEntrySessionStore.suppressAutomaticPublicEntryResume else { return }
        delegate.publicEntryDestination = .welcome
        delegate.clearOnboardingModel()
    }

    func clearExistingUserSessionForMissingCloudProfile() {
        guard let delegate else { return }
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInSessionActive = false
    }

    // MARK: - Route analytics

    func handleEffectiveRouteChange(_ route: AppShellRoute, routeInputs: AuthGateRouteInputs) {
        if route == .welcome {
            logWelcomeScreenAnalytics()
        }
        logAppShellRouteDecision(selectedRoute: route, routeInputs: routeInputs)
    }

    func logAppShellRouteDecision(selectedRoute: AppShellRoute, routeInputs: AuthGateRouteInputs) {
        let base = AuthGateRoutingCoordinator.baseRoute(inputs: routeInputs, container: container)
        AppShellRoutingLogger.logDecision(
            authState: routeInputs.authState,
            rootState: routeInputs.rootState,
            hasLocalProfile: container.profileBootstrapService.hasLocalProfile(),
            localProfileAwaitingSignIn: container.profileBootstrapService.localProfileAwaitingSignIn(),
            hasPersistedOnboardingDraft: container.onboardingDraftStore.hasDraft,
            suppressAutomaticPublicEntryResume: routeInputs.suppressAutomaticPublicEntryResume,
            publicEntryDestination: routeInputs.publicEntryDestination,
            isOnboardingModelReady: routeInputs.isOnboardingModelReady,
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
            profileResolutionResult: profileResolutionResult ?? delegate?.lastExistingUserResolutionResult,
            reason: reason
        )
    }

    func logWelcomeScreenAnalytics() {
        guard let delegate else { return }
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

        guard !delegate.didLogColdStartWelcome else {
            logPublicEntry(.welcomeViewed, properties: base)
            return
        }

        delegate.didLogColdStartWelcome = true
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
        guard let delegate, delegate.existingUserSignInSessionActive else { return }
        logExistingUserSignIn(
            .existingSignInSucceeded,
            profileResolutionResult: delegate.lastExistingUserResolutionResult
        )
        delegate.existingUserSignInSessionActive = false
        delegate.existingUserSignInError = nil
        delegate.pendingExistingUserSignIn = false
    }

    func completeExistingUserSignInNoProfileIfNeeded() {
        guard let delegate, delegate.existingUserSignInSessionActive else { return }
        logExistingUserSignIn(
            .existingSignInNoProfileFound,
            profileResolutionResult: .noProfileFound
        )
        delegate.existingUserSignInSessionActive = false
        delegate.existingUserSignInError = nil
    }

    func completeExistingUserSignInFailure(_ kind: ExistingUserSignInFailureKind) {
        guard let delegate else { return }
        logExistingUserSignIn(.existingSignInFailed, reason: kind)
        delegate.existingUserSignInSessionActive = false
        delegate.pendingExistingUserSignIn = false
        delegate.existingUserSignInError = kind
        delegate.publicEntryDestination = .existingUserSignIn

        if AppRouteResolver.isSignedIn(authManager.authState) {
            delegate.suppressSignOutEntrySourceAnnotation = true
            delegate.prepareAuthenticatedSignOut(source: "existing_user_sign_in_failure")
            delegate.signOutFromAuthManager()
        }
    }

    // MARK: - Private

    private func didSignInAttemptFail(from previous: AuthState, to state: AuthState) -> Bool {
        switch (previous, state) {
        case (.signingIn, .signedOut), (.signingIn, .failed):
            return true
        default:
            return false
        }
    }
}
