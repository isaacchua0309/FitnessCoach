//
//  CoachToolbarUsageStore.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight usage tracking for Coach toolbar ordering.
//

import Foundation

@MainActor
final class CoachToolbarUsageStore {

    static let shared = CoachToolbarUsageStore()

    private let defaults: UserDefaults
    private let keyPrefix = "coach.toolbar.usage."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func usageCount(for action: CoachToolbarAction) -> Int {
        defaults.integer(forKey: storageKey(for: action))
    }

    func recordUse(of action: CoachToolbarAction) {
        let key = storageKey(for: action)
        defaults.set(usageCount(for: action) + 1, forKey: key)
    }

    private func storageKey(for action: CoachToolbarAction) -> String {
        keyPrefix + action.rawValue
    }
}
