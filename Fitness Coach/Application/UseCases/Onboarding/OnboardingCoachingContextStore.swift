//
//  OnboardingCoachingContextStore.swift
//  Fitness Coach
//
//  Persists onboarding coaching context for first Coach session.
//

import Foundation

struct OnboardingCoachingContextStore: Sendable {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder

    init(userDefaults: UserDefaults = .standard, encoder: JSONEncoder = JSONEncoder()) {
        self.userDefaults = userDefaults
        self.encoder = encoder
    }

    func save(_ context: OnboardingCoachingContext) {
        guard let data = try? encoder.encode(context) else { return }
        userDefaults.set(data, forKey: OnboardingCoachingContext.userDefaultsKey)
    }

    func load() -> OnboardingCoachingContext? {
        guard let data = userDefaults.data(forKey: OnboardingCoachingContext.userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(OnboardingCoachingContext.self, from: data)
    }

    func clear() {
        userDefaults.removeObject(forKey: OnboardingCoachingContext.userDefaultsKey)
    }
}
