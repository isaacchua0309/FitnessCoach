//
//  AuthDependencies.swift
//  Fitness Coach
//
//  Typed auth and onboarding dependency bundle for AppContainer wiring.
//

import Foundation

/// Resolved auth session, onboarding preferences, and refresh bus for `AppContainer`.
struct AuthDependencies {
    let refreshCenter: AppRefreshCenter
    let accountRestoreSessionState: AccountRestoreSessionState
    let authManager: AuthManager
    let authUIDCache: AuthUIDCache
    let onboardingUserDefaults: UserDefaults
    let onboardingDraftStore: OnboardingDraftStore
    let publicEntrySessionStore: PublicEntrySessionStore
    let onboardingCoachingContextStore: OnboardingCoachingContextStore
    let onboardingRoutingConfiguration: OnboardingRoutingConfiguration

    /// Builds auth and onboarding shell dependencies for `AppContainer`.
    ///
    /// Injectable `onboardingUserDefaults` and `onboardingRoutingConfiguration`
    /// support tests and previews without changing `AppContainer`'s public initializer.
    static func build(
        inMemory: Bool,
        onboardingUserDefaults: UserDefaults? = nil,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration? = nil
    ) -> AuthDependencies {
        let authManager = AuthManager()
        let authUIDCache = AuthUIDCache()
        authUIDCache.update(uid: authManager.currentUID)

        let userDefaults = makeOnboardingUserDefaults(inMemory: inMemory, override: onboardingUserDefaults)

        return AuthDependencies(
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

    private static func makeOnboardingUserDefaults(
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
