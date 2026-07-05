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
    @Published var accountRestoreViewModel: AccountRestoreViewModel?

    private var loggedAuthGatePhase: AuthGateLoggedPhase?
    private var cancellables = Set<AnyCancellable>()
    private let publicEntryFlowCoordinator: PublicEntryFlowCoordinator
    private let onboardingShellCoordinator: AuthOnboardingShellCoordinator
    private let profileConflictCoordinator: AuthProfileConflictCoordinator
    private let restoreShellCoordinator: AuthRestoreShellCoordinator
    private let signedInShellCoordinator: AuthSignedInShellCoordinator
    #if DEBUG
    private var testingSignedInUID: String?
    #endif

    init(container: AppContainer) {
        self.container = container
        self.authManager = container.authManager
        self.rootModel = container.makeRootModel()
        self.publicEntryFlowCoordinator = PublicEntryFlowCoordinator(
            container: container,
            authManager: container.authManager
        )
        self.onboardingShellCoordinator = AuthOnboardingShellCoordinator(
            container: container,
            authManager: container.authManager
        )
        self.profileConflictCoordinator = AuthProfileConflictCoordinator(
            container: container,
            authManager: container.authManager,
            rootModel: rootModel
        )
        self.restoreShellCoordinator = AuthRestoreShellCoordinator(
            container: container,
            authManager: container.authManager,
            rootModel: rootModel
        )
        self.signedInShellCoordinator = AuthSignedInShellCoordinator(
            container: container,
            authManager: container.authManager,
            rootModel: rootModel,
            profileConflictCoordinator: profileConflictCoordinator,
            restoreShellCoordinator: restoreShellCoordinator
        )

        publicEntryFlowCoordinator.configure(delegate: self)
        onboardingShellCoordinator.configure(delegate: self)
        profileConflictCoordinator.configure(delegate: self)
        restoreShellCoordinator.configure(delegate: self)
        signedInShellCoordinator.configure(delegate: self)

        rootModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        authManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Routing

    private var routeInputs: AuthGateRouteInputs {
        AuthGateRouteInputs(
            authState: authManager.authState,
            rootState: rootModel.state,
            isOnboardingModelReady: onboardingModel != nil,
            awaitingCloudSync: awaitingCloudSync,
            pendingOnboardingCompletion: pendingSignInForOnboardingCompletion,
            publicEntryDestination: publicEntryDestination,
            suppressAutomaticPublicEntryResume:
                container.publicEntrySessionStore.suppressAutomaticPublicEntryResume
        )
    }

    var effectiveRoute: AppShellRoute {
        AuthGateRoutingCoordinator.effectiveRoute(
            inputs: routeInputs,
            container: container
        )
    }

    // MARK: - Public entry actions

    func beginOnboardingFromWelcome() {
        publicEntryFlowCoordinator.beginOnboardingFromWelcome()
    }

    func beginExistingUserSignInFromWelcome() {
        publicEntryFlowCoordinator.beginExistingUserSignInFromWelcome()
    }

    func returnToWelcomeFromExistingUserSignIn() {
        publicEntryFlowCoordinator.returnToWelcomeFromExistingUserSignIn()
    }

    func returnToWelcomeFromOnboarding() {
        publicEntryFlowCoordinator.returnToWelcomeFromOnboarding()
    }

    func beginOnboardingFromExistingUserSignIn() {
        publicEntryFlowCoordinator.beginOnboardingFromExistingUserSignIn()
    }

    func startPreAuthOnboarding() {
        publicEntryFlowCoordinator.startPreAuthOnboarding()
    }

    func signInAsExistingUser() {
        publicEntryFlowCoordinator.signInAsExistingUser()
    }

    func beginOnboardingAfterNoExistingPlan() {
        publicEntryFlowCoordinator.beginOnboardingAfterNoExistingPlan()
    }

    func useAnotherAccountAfterNoExistingPlan() {
        publicEntryFlowCoordinator.useAnotherAccountAfterNoExistingPlan()
    }

    // MARK: - Pre-auth onboarding

    func preparePreAuthOnboardingIfNeeded() {
        onboardingShellCoordinator.preparePreAuthOnboardingIfNeeded()
    }

    // MARK: - Signed-in flow

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

    func signOutFromAccount() {
        signedInShellCoordinator.signOutFromAccount()
    }

    func wireAccountDeletionRouter() {
        signedInShellCoordinator.wireAccountDeletionRouter()
    }

    func handleAccountDeletionCompleted(scope: AccountDeletionScope) {
        signedInShellCoordinator.handleAccountDeletionCompleted(scope: scope)
    }

    func retryAccountMismatchOrOnboardingCloudCheck() {
        profileConflictCoordinator.retryAccountMismatchOrOnboardingCloudCheck()
    }

    // MARK: - Onboarding model lifecycle

    /// Ensures the onboarding model exists whenever routing targets an initializing onboarding shell.
    func bootstrapOnboardingIfNeeded() {
        onboardingShellCoordinator.bootstrapOnboardingIfNeeded()
    }

    func ensurePreAuthOnboardingModel() {
        onboardingShellCoordinator.ensurePreAuthOnboardingModel()
    }

    func ensureOnboardingModel() {
        onboardingShellCoordinator.ensureOnboardingModel()
    }

    func handleOnboardingCompletionRequest() {
        onboardingShellCoordinator.handleOnboardingCompletionRequest()
    }

    func applyOnboardingGoogleSignInOutcome(_ outcome: GoogleSignInAttemptOutcome) {
        onboardingShellCoordinator.applyOnboardingGoogleSignInOutcome(outcome)
    }

    /// Signed-in onboarding completion: probe cloud, then sync or show conflict UI.
    func resolveOnboardingCompletionAfterSignIn(uid: String) async {
        await onboardingShellCoordinator.resolveOnboardingCompletionAfterSignIn(uid: uid)
    }

    func finishOnboardingCompletionAfterSuccessfulSync() {
        onboardingShellCoordinator.finishOnboardingCompletionAfterSuccessfulSync()
    }

    func clearOnboardingCompletionState() {
        onboardingShellCoordinator.clearOnboardingCompletionState()
    }

    func retryOnboardingCompletionCloudCheck() {
        onboardingShellCoordinator.retryOnboardingCompletionCloudCheck()
    }

    func finishOnboardingLocally() {
        onboardingShellCoordinator.finishOnboardingLocally()
    }

    func applyExistingUserGoogleSignInOutcome(_ outcome: GoogleSignInAttemptOutcome) {
        publicEntryFlowCoordinator.applyExistingUserGoogleSignInOutcome(outcome)
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

    func syncUnsyncedLocalProfile(uid: String) {
        signedInShellCoordinator.syncUnsyncedLocalProfile(uid: uid)
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

    // MARK: - Auth / root reactions

    func handleAuthStateChange(from previous: AuthState, to state: AuthState) {
        signedInShellCoordinator.handleAuthStateChange(from: previous, to: state)
    }

    func prepareAuthenticatedSignOut(source: String) {
        signedInShellCoordinator.prepareAuthenticatedSignOut(source: source)
    }

    func reconcileSignedInProfile(uid: String, isFreshSignIn: Bool) {
        signedInShellCoordinator.reconcileSignedInProfile(uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func handleSignedOutTransition(
        from previous: AuthState,
        to state: AuthState,
        wasSignedIn: Bool
    ) {
        signedInShellCoordinator.handleSignedOutTransition(
            from: previous,
            to: state,
            wasSignedIn: wasSignedIn
        )
    }

    // MARK: - Account restore routing

    func routeToMainWithAccountRestore(uid: String, reason: AccountRestoreReason) {
        restoreShellCoordinator.routeToMainWithAccountRestore(uid: uid, reason: reason)
    }

    func completeRouteToMain(uid: String, restoreSummary: AccountRestoreSummary? = nil) {
        restoreShellCoordinator.completeRouteToMain(uid: uid, restoreSummary: restoreSummary)
    }

    func scheduleRouteToMainWithAccountRestore(uid: String, reason: AccountRestoreReason) {
        restoreShellCoordinator.scheduleRouteToMainWithAccountRestore(uid: uid, reason: reason)
    }

    func retryAccountRestore() {
        restoreShellCoordinator.retryAccountRestore()
    }

    func isUIDStillCurrent(_ uid: String) -> Bool {
        #if DEBUG
        if let testingSignedInUID {
            return testingSignedInUID == uid
        }
        #endif
        return authManager.currentUID == uid
    }

    func runExistingUserSignInResolution(uid: String, isFreshSignIn: Bool) async {
        await signedInShellCoordinator.runExistingUserSignInResolution(uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func applyExistingUserSignInResolution(
        _ result: ExistingUserSignInResolutionResult,
        uid: String
    ) {
        signedInShellCoordinator.applyExistingUserSignInResolution(result, uid: uid)
    }

    func retryExistingUserProfileResolution() {
        signedInShellCoordinator.retryExistingUserProfileResolution()
    }

    func applyReconcileDecision(
        _ decision: SignedInProfileReconcileDecision,
        uid: String,
        isFreshSignIn: Bool
    ) {
        signedInShellCoordinator.applyReconcileDecision(decision, uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func performOwnershipCloudLookup(uid: String, isFreshSignIn: Bool) {
        signedInShellCoordinator.performOwnershipCloudLookup(uid: uid, isFreshSignIn: isFreshSignIn)
    }

    func presentProfileConflictAfterLookup(uid: String) {
        profileConflictCoordinator.presentProfileConflictAfterLookup(uid: uid)
    }

    func handleRootStateChange(_ state: RootViewState) {
        signedInShellCoordinator.handleRootStateChange(state)
    }

    func handleEffectiveRouteChange(_ route: AppShellRoute) {
        logAuthGatePhaseIfNeeded(for: route)
        publicEntryFlowCoordinator.handleEffectiveRouteChange(route, routeInputs: routeInputs)
    }

    private func logAuthGatePhaseIfNeeded(for route: AppShellRoute) {
        let phase: AuthGateLoggedPhase = AppRouteResolver.isSignedIn(authManager.authState)
            ? .signedIn
            : .signedOut
        guard loggedAuthGatePhase != phase else { return }
        loggedAuthGatePhase = phase

        let routeName = String(describing: route)
        switch phase {
        case .signedOut:
            AuthSignInDebugLogger.authGateRenderedSignedOut(route: routeName)
        case .signedIn:
            AuthSignInDebugLogger.authGateRenderedSignedIn(route: routeName)
        }
    }

    private enum AuthGateLoggedPhase: Equatable {
        case signedOut
        case signedIn
    }

    // MARK: - Public entry analytics

    func logAppShellRouteDecision(selectedRoute: AppShellRoute) {
        publicEntryFlowCoordinator.logAppShellRouteDecision(
            selectedRoute: selectedRoute,
            routeInputs: routeInputs
        )
    }

    func publicEntryAnalyticsProperties(
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil,
        reason: String? = nil
    ) -> PublicEntryAnalyticsProperties {
        publicEntryFlowCoordinator.publicEntryAnalyticsProperties(
            profileResolutionResult: profileResolutionResult,
            reason: reason
        )
    }

    func logWelcomeScreenAnalytics() {
        publicEntryFlowCoordinator.logWelcomeScreenAnalytics()
    }

    func logPublicEntry(
        _ event: PublicEntryAnalyticsEvent,
        properties: PublicEntryAnalyticsProperties
    ) {
        publicEntryFlowCoordinator.logPublicEntry(event, properties: properties)
    }

    // MARK: - Existing user sign-in analytics

    func logExistingUserSignIn(
        _ event: PublicEntryAnalyticsEvent,
        reason: ExistingUserSignInFailureKind? = nil,
        profileResolutionResult: ExistingUserSignInResolutionResult? = nil
    ) {
        publicEntryFlowCoordinator.logExistingUserSignIn(
            event,
            reason: reason,
            profileResolutionResult: profileResolutionResult
        )
    }

    func completeExistingUserSignInSuccessIfNeeded() {
        publicEntryFlowCoordinator.completeExistingUserSignInSuccessIfNeeded()
    }

    func completeExistingUserSignInNoProfileIfNeeded() {
        publicEntryFlowCoordinator.completeExistingUserSignInNoProfileIfNeeded()
    }

    func completeExistingUserSignInFailure(_ kind: ExistingUserSignInFailureKind) {
        publicEntryFlowCoordinator.completeExistingUserSignInFailure(kind)
    }

    func retryProfileLoad() {
        signedInShellCoordinator.retryProfileLoad()
    }
}

#if DEBUG
extension AuthGateCoordinator {
    func applyTestingSignedInUID(_ uid: String) {
        testingSignedInUID = uid
    }
}
#endif
