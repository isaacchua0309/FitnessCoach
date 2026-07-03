//
//  HealthSummaryRemoteSyncStateStore.swift
//  Fitness Coach
//
//  Forma — Persists remote Health Summary Sync timestamps per authenticated user.
//

import Foundation

protocol HealthSummaryRemoteSyncStateStoring: Sendable {
    func load(for userID: String?) -> HealthSummaryRemoteSyncPersistedState
    func save(_ state: HealthSummaryRemoteSyncPersistedState, for userID: String?)
    func clear(for userID: String?)
}

struct UserDefaultsHealthSummaryRemoteSyncStateStore: HealthSummaryRemoteSyncStateStoring {

    private let userDefaults: UserDefaults
    private let keyPrefix: String

    init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "forma.healthSummaryRemoteSync"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }

    func load(for userID: String?) -> HealthSummaryRemoteSyncPersistedState {
        guard let userID = normalizedUserID(userID),
              let data = userDefaults.data(forKey: storageKey(for: userID)),
              let decoded = try? JSONDecoder().decode(HealthSummaryRemoteSyncPersistedState.self, from: data) else {
            return .empty
        }
        return decoded
    }

    func save(_ state: HealthSummaryRemoteSyncPersistedState, for userID: String?) {
        guard let userID = normalizedUserID(userID),
              let data = try? JSONEncoder().encode(state) else {
            return
        }
        userDefaults.set(data, forKey: storageKey(for: userID))
    }

    func clear(for userID: String?) {
        guard let userID = normalizedUserID(userID) else { return }
        userDefaults.removeObject(forKey: storageKey(for: userID))
    }

    private func storageKey(for userID: String) -> String {
        "\(keyPrefix).\(userID)"
    }

    private func normalizedUserID(_ userID: String?) -> String? {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty, trimmed != HealthCachePolicy.anonymousUserID else {
            return nil
        }
        return trimmed
    }
}

final class LockedHealthSummaryRemoteSyncStateStore: HealthSummaryRemoteSyncStateStoring, @unchecked Sendable {

    private var states: [String: HealthSummaryRemoteSyncPersistedState] = [:]
    private let lock = NSLock()

    func load(for userID: String?) -> HealthSummaryRemoteSyncPersistedState {
        guard let userID else { return .empty }
        lock.lock()
        defer { lock.unlock() }
        return states[userID] ?? .empty
    }

    func save(_ state: HealthSummaryRemoteSyncPersistedState, for userID: String?) {
        guard let userID else { return }
        lock.lock()
        states[userID] = state
        lock.unlock()
    }

    func clear(for userID: String?) {
        guard let userID else { return }
        lock.lock()
        states.removeValue(forKey: userID)
        lock.unlock()
    }
}
