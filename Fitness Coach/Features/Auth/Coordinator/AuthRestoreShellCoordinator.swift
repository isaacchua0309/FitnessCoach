//
//  AuthRestoreShellCoordinator.swift
//  Fitness Coach
//
//  Account restore routing and restore view-model lifecycle for the auth gate shell.
//

import Foundation

@MainActor
protocol AuthRestoreShellCoordinatorDelegate: AnyObject {
    var accountRestoreViewModel: AccountRestoreViewModel? { get set }
    var awaitingCloudSync: Bool { get set }
    var pendingExistingUserSignIn: Bool { get set }

    func isUIDStillCurrent(_ uid: String) -> Bool
    func currentUID() -> String?
    func completeExistingUserSignInSuccessIfNeeded()
    func prepareAuthenticatedSignOut(source: String)
    func signOutFromAuthManager()
}

@MainActor
final class AuthRestoreShellCoordinator {

    private weak var delegate: AuthRestoreShellCoordinatorDelegate?
    private let container: AppContainer
    private let authManager: AuthManager
    private let rootModel: RootModel
    private var accountRestoreRouteTask: Task<Void, Never>?

    init(container: AppContainer, authManager: AuthManager, rootModel: RootModel) {
        self.container = container
        self.authManager = authManager
        self.rootModel = rootModel
    }

    func configure(delegate: AuthRestoreShellCoordinatorDelegate) {
        self.delegate = delegate
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

    func cancelRestorePresentation() {
        accountRestoreRouteTask?.cancel()
        accountRestoreRouteTask = nil
        delegate?.accountRestoreViewModel = nil
    }

    // MARK: - Private

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
            self.delegate?.prepareAuthenticatedSignOut(source: "account_restore_failed_sign_out")
            self.delegate?.signOutFromAuthManager()
        }
        return viewModel
    }
}
