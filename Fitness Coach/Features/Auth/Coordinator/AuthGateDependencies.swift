//
//  AuthGateDependencies.swift
//  Fitness Coach
//
//  Coordinator wiring and assembly for AuthGateCoordinator.
//

import Foundation

@MainActor
struct AuthGateDependencies {
    let container: AppContainer
    let rootModel: RootModel
    let publicEntry: PublicEntryFlowCoordinator
    let onboardingShell: AuthOnboardingShellCoordinator
    let profileConflict: AuthProfileConflictCoordinator
    let restoreShell: AuthRestoreShellCoordinator
    let signedInShell: AuthSignedInShellCoordinator

    static func live(container: AppContainer) -> AuthGateDependencies {
        let rootModel = container.makeRootModel()
        let authManager = container.authManager

        let publicEntry = PublicEntryFlowCoordinator(
            container: container,
            authManager: authManager
        )
        let onboardingShell = AuthOnboardingShellCoordinator(
            container: container,
            authManager: authManager
        )
        let profileConflict = AuthProfileConflictCoordinator(
            container: container,
            authManager: authManager,
            rootModel: rootModel
        )
        let restoreShell = AuthRestoreShellCoordinator(
            container: container,
            authManager: authManager,
            rootModel: rootModel
        )
        let signedInShell = AuthSignedInShellCoordinator(
            container: container,
            authManager: authManager,
            rootModel: rootModel,
            profileConflictCoordinator: profileConflict,
            restoreShellCoordinator: restoreShell
        )

        return AuthGateDependencies(
            container: container,
            rootModel: rootModel,
            publicEntry: publicEntry,
            onboardingShell: onboardingShell,
            profileConflict: profileConflict,
            restoreShell: restoreShell,
            signedInShell: signedInShell
        )
    }

    #if DEBUG
    static func testing(
        container: AppContainer,
        rootModel: RootModel? = nil,
        publicEntry: PublicEntryFlowCoordinator? = nil,
        onboardingShell: AuthOnboardingShellCoordinator? = nil,
        profileConflict: AuthProfileConflictCoordinator? = nil,
        restoreShell: AuthRestoreShellCoordinator? = nil,
        signedInShell: AuthSignedInShellCoordinator? = nil
    ) -> AuthGateDependencies {
        let resolvedRootModel = rootModel ?? container.makeRootModel()
        let authManager = container.authManager

        let resolvedPublicEntry = publicEntry ?? PublicEntryFlowCoordinator(
            container: container,
            authManager: authManager
        )
        let resolvedOnboardingShell = onboardingShell ?? AuthOnboardingShellCoordinator(
            container: container,
            authManager: authManager
        )
        let resolvedProfileConflict = profileConflict ?? AuthProfileConflictCoordinator(
            container: container,
            authManager: authManager,
            rootModel: resolvedRootModel
        )
        let resolvedRestoreShell = restoreShell ?? AuthRestoreShellCoordinator(
            container: container,
            authManager: authManager,
            rootModel: resolvedRootModel
        )
        let resolvedSignedInShell = signedInShell ?? AuthSignedInShellCoordinator(
            container: container,
            authManager: authManager,
            rootModel: resolvedRootModel,
            profileConflictCoordinator: resolvedProfileConflict,
            restoreShellCoordinator: resolvedRestoreShell
        )

        return AuthGateDependencies(
            container: container,
            rootModel: resolvedRootModel,
            publicEntry: resolvedPublicEntry,
            onboardingShell: resolvedOnboardingShell,
            profileConflict: resolvedProfileConflict,
            restoreShell: resolvedRestoreShell,
            signedInShell: resolvedSignedInShell
        )
    }
    #endif
}

// Route resolution remains stateless via `AuthGateRoutingCoordinator`.
