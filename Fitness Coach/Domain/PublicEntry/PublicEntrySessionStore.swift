//
//  PublicEntrySessionStore.swift
//  Fitness Coach
//
//  Forma — Persists public-entry resume policy across launches.
//

import Foundation
import SwiftUI

/// Tracks whether automatic draft / save-plan resume should bypass welcome.
final class PublicEntrySessionStore: @unchecked Sendable {

    private let userDefaults: UserDefaults
    private let suppressAutomaticResumeKey = "forma.publicEntry.suppressAutomaticResume"
    private let pendingEntrySourceKey = "forma.publicEntry.pendingEntrySource"

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var suppressAutomaticPublicEntryResume: Bool {
        userDefaults.bool(forKey: suppressAutomaticResumeKey)
    }

    func markExplicitSignOut() {
        userDefaults.set(true, forKey: suppressAutomaticResumeKey)
    }

    func clearExplicitSignOut() {
        userDefaults.removeObject(forKey: suppressAutomaticResumeKey)
    }

    func markUserInitiatedLogout() {
        userDefaults.set(PublicEntryEntrySource.logout.rawValue, forKey: pendingEntrySourceKey)
    }

    func markSessionExpiredLogout() {
        guard userDefaults.string(forKey: pendingEntrySourceKey) == nil else { return }
        userDefaults.set(PublicEntryEntrySource.sessionExpired.rawValue, forKey: pendingEntrySourceKey)
    }

    var pendingEntrySource: PublicEntryEntrySource? {
        guard let raw = userDefaults.string(forKey: pendingEntrySourceKey) else { return nil }
        return PublicEntryEntrySource(rawValue: raw)
    }

    func consumePendingEntrySource() -> PublicEntryEntrySource? {
        defer { userDefaults.removeObject(forKey: pendingEntrySourceKey) }
        guard let raw = userDefaults.string(forKey: pendingEntrySourceKey) else { return nil }
        return PublicEntryEntrySource(rawValue: raw)
    }
}

// MARK: - SwiftUI environment

private struct PublicEntrySessionStoreEnvironmentKey: EnvironmentKey {
    static let defaultValue: PublicEntrySessionStore? = nil
}

extension EnvironmentValues {
    var publicEntrySessionStore: PublicEntrySessionStore? {
        get { self[PublicEntrySessionStoreEnvironmentKey.self] }
        set { self[PublicEntrySessionStoreEnvironmentKey.self] = newValue }
    }
}
