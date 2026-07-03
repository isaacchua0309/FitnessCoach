//
//  HealthSummarySyncConsentStore.swift
//  Fitness Coach
//
//  Forma — Persists and publishes user consent for remote Health Summary Sync.
//

import Combine
import Foundation

protocol HealthSummarySyncConsentStoring: Sendable {
    func load(for userID: String?) -> HealthSummarySyncConsentState
    func save(_ state: HealthSummarySyncConsentState, for userID: String?)
    func clear(for userID: String?)
}

struct UserDefaultsHealthSummarySyncConsentStore: HealthSummarySyncConsentStoring {

    private let userDefaults: UserDefaults
    private let keyPrefix: String

    init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "forma.healthSummaryRemoteSyncConsent"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }

    func load(for userID: String?) -> HealthSummarySyncConsentState {
        guard let userID = normalizedUserID(userID),
              let data = userDefaults.data(forKey: storageKey(for: userID)),
              let decoded = try? JSONDecoder().decode(HealthSummarySyncConsentState.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save(_ state: HealthSummarySyncConsentState, for userID: String?) {
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

final class LockedHealthSummarySyncConsentStore: HealthSummarySyncConsentStoring, @unchecked Sendable {

    private var states: [String: HealthSummarySyncConsentState] = [:]
    private let lock = NSLock()

    func load(for userID: String?) -> HealthSummarySyncConsentState {
        guard let userID else { return .default }
        lock.lock()
        defer { lock.unlock() }
        return states[userID] ?? .default
    }

    func save(_ state: HealthSummarySyncConsentState, for userID: String?) {
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

@MainActor
final class HealthSummarySyncConsentStore: ObservableObject {

    @Published private(set) var state: HealthSummarySyncConsentState = .default

    private let storage: any HealthSummarySyncConsentStoring
    private let userProvider: any HealthCacheUserProviding

    init(
        storage: any HealthSummarySyncConsentStoring = UserDefaultsHealthSummarySyncConsentStore(),
        userProvider: any HealthCacheUserProviding
    ) {
        self.storage = storage
        self.userProvider = userProvider
        refresh()
    }

    func refresh() {
        state = storage.load(for: userProvider.currentUserID())
    }

    func optIn() {
        let updated = HealthSummarySyncConsentState(
            decision: .optedIn,
            updatedAt: Date()
        )
        storage.save(updated, for: userProvider.currentUserID())
        state = updated
    }

    func optOut() {
        let updated = HealthSummarySyncConsentState(
            decision: .optedOut,
            updatedAt: Date()
        )
        storage.save(updated, for: userProvider.currentUserID())
        state = updated
    }

    func resetForCurrentUser() {
        storage.clear(for: userProvider.currentUserID())
        state = .default
    }
}

enum HealthSummarySyncConsentResolver {

    static func isRemoteSyncActive(
        storage: any HealthSummarySyncConsentStoring,
        userProvider: any HealthCacheUserProviding,
        featureFlagEnabled: Bool = HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
    ) -> Bool {
        HealthSummaryRemoteSyncGate.isActive(
            consent: storage.load(for: userProvider.currentUserID()),
            featureFlagEnabled: featureFlagEnabled
        )
    }
}
