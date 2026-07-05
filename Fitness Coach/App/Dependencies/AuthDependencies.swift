//
//  AuthDependencies.swift
//  Fitness Coach
//
//  Auth session and onboarding preference construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation

extension AppContainer {

    struct AuthDependenciesBundle {
        let refreshCenter: AppRefreshCenter
        let accountRestoreSessionState: AccountRestoreSessionState
        let authManager: AuthManager
        let authUIDCache: AuthUIDCache
        let onboardingUserDefaults: UserDefaults
        let onboardingDraftStore: OnboardingDraftStore
        let publicEntrySessionStore: PublicEntrySessionStore
        let onboardingCoachingContextStore: OnboardingCoachingContextStore
        let onboardingRoutingConfiguration: OnboardingRoutingConfiguration
    }

    static func buildAuthDependencies(
        inMemory: Bool,
        onboardingUserDefaults: UserDefaults?,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration?
    ) -> AuthDependenciesBundle {
        let authManager = AuthManager()
        let authUIDCache = AuthUIDCache()
        authUIDCache.update(uid: authManager.currentUID)

        let userDefaults = makeOnboardingUserDefaults(inMemory: inMemory, override: onboardingUserDefaults)

        return AuthDependenciesBundle(
            refreshCenter: AppRefreshCenter(),
            accountRestoreSessionState: AccountRestoreSessionState(),
            authManager: authManager,
            authUIDCache: authUIDCache,
            onboardingUserDefaults: userDefaults,
            onboardingDraftStore: OnboardingDraftStore(userDefaults: userDefaults),
            publicEntrySessionStore: PublicEntrySessionStore(userDefaults: userDefaults),
            onboardingCoachingContextStore: OnboardingCoachingContextStore(userDefaults: userDefaults),
            onboardingRoutingConfiguration: onboardingRoutingConfiguration ?? .production
        )
    }

    static func makeOnboardingUserDefaults(
        inMemory: Bool,
        override: UserDefaults?
    ) -> UserDefaults {
        if let override {
            return override
        }
        if inMemory {
            let suiteName = "FitnessCoach.onboarding.inMemory.\(UUID().uuidString)"
            return UserDefaults(suiteName: suiteName) ?? .standard
        }
        return .standard
    }
}
