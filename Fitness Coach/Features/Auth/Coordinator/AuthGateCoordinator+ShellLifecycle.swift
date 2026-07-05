//
//  AuthGateCoordinator+ShellLifecycle.swift
//  Fitness Coach
//
//  Shell activation, environment accessors, and internal lifecycle reactions.
//

import Combine
import Foundation

extension AuthGateCoordinator {

    // MARK: - Shell environment accessors

    var publicEntrySessionStore: PublicEntrySessionStore {
        container.publicEntrySessionStore
    }

    var accountDeletionCoordinator: AccountDeletionCoordinator {
        container.accountDeletionCoordinator
    }

    var settingsPrivacyDataEnvironment: SettingsPrivacyDataEnvironment {
        container.makeSettingsPrivacyDataEnvironment()
    }

    var publicEntryAnalyticsLogger: any PublicEntryAnalyticsLogging {
        container.publicEntryAnalyticsLogger
    }

    var isUserSignedIn: Bool {
        AppRouteResolver.isSignedIn(authManager.authState)
    }

    func localProfileForPlanConflict() -> UserProfile? {
        try? container.userProfileService.getCurrentProfile()
    }

    // MARK: - Shell activation

    func activateShell() {
        guard !didActivateShell else { return }
        didActivateShell = true

        authManager.startListening()
        wireAccountDeletionRouter()
        wireShellReactions()
    }

    private func wireShellReactions() {
        let initialAuthState = authManager.authState
        handleAuthStateChange(from: initialAuthState, to: initialAuthState)
        handleRootStateChange(rootModel.state)

        lastHandledRoute = effectiveRoute
        handleEffectiveRouteChange(effectiveRoute)

        authManager.$authState
            .scan((initialAuthState, initialAuthState)) { ($0.1, $1) }
            .dropFirst()
            .sink { [weak self] previous, state in
                self?.handleAuthStateChange(from: previous, to: state)
            }
            .store(in: &shellReactionCancellables)

        rootModel.$state
            .dropFirst()
            .sink { [weak self] state in
                self?.handleRootStateChange(state)
            }
            .store(in: &shellReactionCancellables)

        Publishers.CombineLatest4(
            authManager.$authState,
            rootModel.$state,
            $onboardingModel.map { $0 != nil }.removeDuplicates(),
            $publicEntryDestination.removeDuplicates()
        )
        .combineLatest(
            $awaitingCloudSync.removeDuplicates(),
            $pendingSignInForOnboardingCompletion.removeDuplicates()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.refreshEffectiveRouteIfNeeded()
        }
        .store(in: &shellReactionCancellables)

        container.cloudUploadFailureNotifier.$pendingContext
            .compactMap { $0 }
            .sink { [weak self] context in
                self?.presentCloudProfileUploadFailure(context: context)
            }
            .store(in: &shellReactionCancellables)
    }

    private func refreshEffectiveRouteIfNeeded() {
        let route = effectiveRoute
        guard route != lastHandledRoute else { return }
        lastHandledRoute = route
        handleEffectiveRouteChange(route)
    }
}
