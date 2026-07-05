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

    let publicEntryFlowCoordinator: PublicEntryFlowCoordinator
    let onboardingShellCoordinator: AuthOnboardingShellCoordinator
    let profileConflictCoordinator: AuthProfileConflictCoordinator
    let restoreShellCoordinator: AuthRestoreShellCoordinator
    let signedInShellCoordinator: AuthSignedInShellCoordinator

    #if DEBUG
    var testingSignedInUID: String?
    #endif

    init(dependencies: AuthGateDependencies) {
        self.container = dependencies.container
        self.authManager = dependencies.container.authManager
        self.rootModel = dependencies.rootModel
        self.publicEntryFlowCoordinator = dependencies.publicEntry
        self.onboardingShellCoordinator = dependencies.onboardingShell
        self.profileConflictCoordinator = dependencies.profileConflict
        self.restoreShellCoordinator = dependencies.restoreShell
        self.signedInShellCoordinator = dependencies.signedInShell

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

    convenience init(container: AppContainer) {
        self.init(dependencies: .live(container: container))
    }

    // MARK: - Shared delegate bridges

    func currentUID() -> String? {
        authManager.currentUID
    }

    func signOutFromAuthManager() {
        authManager.signOut()
    }

    func clearOnboardingModel() {
        onboardingShellCoordinator.clearOnboardingModel()
    }

    func isUIDStillCurrent(_ uid: String) -> Bool {
        #if DEBUG
        if let testingSignedInUID {
            return testingSignedInUID == uid
        }
        #endif
        return authManager.currentUID == uid
    }

    // MARK: - Routing

    var routeInputs: AuthGateRouteInputs {
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
}

#if DEBUG
extension AuthGateCoordinator {
    func applyTestingSignedInUID(_ uid: String) {
        testingSignedInUID = uid
    }

    func clearTestingSignedInUID() {
        testingSignedInUID = nil
    }
}
#endif
