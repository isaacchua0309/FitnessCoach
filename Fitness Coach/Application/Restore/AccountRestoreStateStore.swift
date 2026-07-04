//
//  AccountRestoreStateStore.swift
//  Fitness Coach
//
//  Forma — Per-UID restore completion metadata in UserDefaults (Phase 4).
//
//  Stores status and timestamps only. Never persists food names, weights,
//  calories, review text, or other personal nutrition content.
//

import Foundation

struct AccountRestoreStoredState: Codable, Equatable, Sendable {
    let uid: String
    let status: AccountRestoreStatus
    let lastStartedAt: Date?
    let lastCompletedAt: Date?
    let lastSuccessfulBlockingRestoreAt: Date?
    let lastSuccessfulBackgroundBackfillAt: Date?
    let lastFailureMessage: String?
    let restoredSchemaVersion: Int?
    let lastRestoreAppVersion: String?
}

protocol AccountRestoreStateStoring {
    func loadState(uid: String) -> AccountRestoreStoredState
    func markStarted(uid: String, reason: AccountRestoreReason, mode: AccountRestoreMode, now: Date)
    func markProgress(uid: String, status: AccountRestoreStatus, now: Date)
    func markCompleted(uid: String, summary: AccountRestoreSummary, now: Date)
    func markPartial(uid: String, summary: AccountRestoreSummary, now: Date)
    func markOffline(uid: String, reason: AccountRestoreReason, now: Date)
    func markFailed(uid: String, reason: AccountRestoreReason, message: String, now: Date)
    func markSkipped(uid: String, reason: AccountRestoreReason, now: Date)
    func prepareForManualRetry(uid: String, now: Date)
    func markBackgroundBackfillStarted(uid: String, now: Date)
    func shouldRunBlockingRestore(uid: String, localDataStatus: AccountLocalDataStatus, now: Date) -> Bool
    func shouldRunBackgroundBackfill(uid: String, now: Date) -> Bool
    func clear(uid: String)
}

enum AccountRestoreStateStoreSupport {

    static let keyPrefix = "forma.accountRestore"

    static func normalizedUID(_ uid: String) -> String? {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func statusKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).status"
    }

    static func lastStartedAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastStartedAt"
    }

    static func lastCompletedAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastCompletedAt"
    }

    static func lastSuccessfulBlockingRestoreAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastSuccessfulBlockingRestoreAt"
    }

    static func lastSuccessfulBackgroundBackfillAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastSuccessfulBackgroundBackfillAt"
    }

    static func lastFailureMessageKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastFailureMessage"
    }

    static func restoredSchemaVersionKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).restoredSchemaVersion"
    }

    static func lastRestoreAppVersionKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastRestoreAppVersion"
    }

    static func allKeys(for uid: String) -> [String] {
        [
            statusKey(for: uid),
            lastStartedAtKey(for: uid),
            lastCompletedAtKey(for: uid),
            lastSuccessfulBlockingRestoreAtKey(for: uid),
            lastSuccessfulBackgroundBackfillAtKey(for: uid),
            lastFailureMessageKey(for: uid),
            restoredSchemaVersionKey(for: uid),
            lastRestoreAppVersionKey(for: uid)
        ]
    }

    static func sanitizedFailureMessage(_ message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Restore failed." }
        return String(trimmed.prefix(240))
    }

    static var currentSchemaVersion: Int {
        FormaSwiftDataMigrationGate.coachV2SchemaVersion
    }

    static func currentAppVersion(bundle: Bundle = .main) -> String? {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let trimmed = version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AccountRestoreStateStore: AccountRestoreStateStoring {

    private let userDefaults: UserDefaults
    private let bundle: Bundle
    private let schemaVersionProvider: () -> Int
    private let appVersionProvider: () -> String?

    init(
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        schemaVersionProvider: @escaping () -> Int = { AccountRestoreStateStoreSupport.currentSchemaVersion },
        appVersionProvider: (() -> String?)? = nil
    ) {
        self.userDefaults = userDefaults
        self.bundle = bundle
        self.schemaVersionProvider = schemaVersionProvider
        self.appVersionProvider = appVersionProvider ?? { AccountRestoreStateStoreSupport.currentAppVersion(bundle: bundle) }
    }

    func loadState(uid: String) -> AccountRestoreStoredState {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else {
            return Self.emptyState(uid: uid)
        }

        let statusRaw = userDefaults.string(forKey: AccountRestoreStateStoreSupport.statusKey(for: normalizedUID))
        let status = statusRaw.flatMap(AccountRestoreStatus.init(rawValue:)) ?? .notStarted

        return AccountRestoreStoredState(
            uid: normalizedUID,
            status: status,
            lastStartedAt: date(forKey: AccountRestoreStateStoreSupport.lastStartedAtKey(for: normalizedUID)),
            lastCompletedAt: date(forKey: AccountRestoreStateStoreSupport.lastCompletedAtKey(for: normalizedUID)),
            lastSuccessfulBlockingRestoreAt: date(
                forKey: AccountRestoreStateStoreSupport.lastSuccessfulBlockingRestoreAtKey(for: normalizedUID)
            ),
            lastSuccessfulBackgroundBackfillAt: date(
                forKey: AccountRestoreStateStoreSupport.lastSuccessfulBackgroundBackfillAtKey(for: normalizedUID)
            ),
            lastFailureMessage: userDefaults.string(
                forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: normalizedUID)
            ),
            restoredSchemaVersion: optionalInt(
                forKey: AccountRestoreStateStoreSupport.restoredSchemaVersionKey(for: normalizedUID)
            ),
            lastRestoreAppVersion: userDefaults.string(
                forKey: AccountRestoreStateStoreSupport.lastRestoreAppVersionKey(for: normalizedUID)
            )
        )
    }

    func markStarted(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        now: Date
    ) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        _ = reason
        _ = mode

        setStatus(.checking, uid: normalizedUID)
        setDate(now, forKey: AccountRestoreStateStoreSupport.lastStartedAtKey(for: normalizedUID))
        removeValue(forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: normalizedUID))
    }

    func markProgress(uid: String, status: AccountRestoreStatus, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        _ = now
        guard status.isInProgress || status == .checking else { return }
        setStatus(status, uid: normalizedUID)
    }

    func markCompleted(uid: String, summary: AccountRestoreSummary, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        applyTerminalOutcome(
            uid: normalizedUID,
            status: .completed,
            mode: summary.mode,
            now: now,
            failureMessage: nil
        )
    }

    func markPartial(uid: String, summary: AccountRestoreSummary, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        applyTerminalOutcome(
            uid: normalizedUID,
            status: .partial,
            mode: summary.mode,
            now: now,
            failureMessage: nil
        )
    }

    func markOffline(uid: String, reason: AccountRestoreReason, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        _ = reason

        setStatus(.offline, uid: normalizedUID)
        setDate(now, forKey: AccountRestoreStateStoreSupport.lastCompletedAtKey(for: normalizedUID))
        removeValue(forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: normalizedUID))
    }

    func markFailed(uid: String, reason: AccountRestoreReason, message: String, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        _ = reason

        setStatus(.failed, uid: normalizedUID)
        setDate(now, forKey: AccountRestoreStateStoreSupport.lastCompletedAtKey(for: normalizedUID))
        userDefaults.set(
            AccountRestoreStateStoreSupport.sanitizedFailureMessage(message),
            forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: normalizedUID)
        )
    }

    func markSkipped(uid: String, reason: AccountRestoreReason, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        _ = reason

        setStatus(.skipped, uid: normalizedUID)
        setDate(now, forKey: AccountRestoreStateStoreSupport.lastCompletedAtKey(for: normalizedUID))
        removeValue(forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: normalizedUID))
    }

    func prepareForManualRetry(uid: String, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        _ = now

        let state = loadState(uid: normalizedUID)
        if state.status.isInProgress {
            setStatus(.notStarted, uid: normalizedUID)
        }
        removeValue(forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: normalizedUID))
    }

    func markBackgroundBackfillStarted(uid: String, now: Date) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        setDate(now, forKey: AccountRestoreStateStoreSupport.lastStartedAtKey(for: normalizedUID))
    }

    func shouldRunBlockingRestore(
        uid: String,
        localDataStatus: AccountLocalDataStatus,
        now: Date
    ) -> Bool {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return false }
        _ = now
        guard localDataStatus.uid == normalizedUID else { return false }
        guard localDataStatus.needsInitialRestore else { return false }

        let state = loadState(uid: normalizedUID)
        guard !state.status.isInProgress else { return false }
        guard state.lastSuccessfulBlockingRestoreAt == nil else { return false }
        return true
    }

    func shouldRunBackgroundBackfill(uid: String, now: Date) -> Bool {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return false }
        _ = now

        let state = loadState(uid: normalizedUID)
        guard !state.status.isInProgress else { return false }
        guard blockingRestoreRequirementSatisfied(state) else { return false }

        if state.status == .partial || state.status == .offline {
            return true
        }

        if state.lastSuccessfulBackgroundBackfillAt == nil {
            return true
        }

        return shouldRerunBackfill(for: state)
    }

    func clear(uid: String) {
        guard let normalizedUID = AccountRestoreStateStoreSupport.normalizedUID(uid) else { return }
        for key in AccountRestoreStateStoreSupport.allKeys(for: normalizedUID) {
            removeValue(forKey: key)
        }
    }

    // MARK: - Private

    private func applyTerminalOutcome(
        uid: String,
        status: AccountRestoreStatus,
        mode: AccountRestoreMode,
        now: Date,
        failureMessage: String?
    ) {
        setStatus(status, uid: uid)
        setDate(now, forKey: AccountRestoreStateStoreSupport.lastCompletedAtKey(for: uid))
        removeValue(forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: uid))

        switch mode {
        case .blockingInitial, .manualRetry:
            if status == .completed || status == .partial || status == .offline || status == .skipped {
                setDate(now, forKey: AccountRestoreStateStoreSupport.lastSuccessfulBlockingRestoreAtKey(for: uid))
            }
        case .backgroundBackfill:
            if status == .completed {
                setDate(now, forKey: AccountRestoreStateStoreSupport.lastSuccessfulBackgroundBackfillAtKey(for: uid))
            }
        }

        userDefaults.set(schemaVersionProvider(), forKey: AccountRestoreStateStoreSupport.restoredSchemaVersionKey(for: uid))
        if let appVersion = appVersionProvider() {
            userDefaults.set(appVersion, forKey: AccountRestoreStateStoreSupport.lastRestoreAppVersionKey(for: uid))
        }

        if let failureMessage {
            userDefaults.set(
                AccountRestoreStateStoreSupport.sanitizedFailureMessage(failureMessage),
                forKey: AccountRestoreStateStoreSupport.lastFailureMessageKey(for: uid)
            )
        }
    }

    private func blockingRestoreRequirementSatisfied(_ state: AccountRestoreStoredState) -> Bool {
        if state.lastSuccessfulBlockingRestoreAt != nil {
            return true
        }
        switch state.status {
        case .skipped, .completed, .partial, .offline:
            return true
        case .notStarted, .checking, .restoringProfile, .restoringRecentData,
             .restoringWeightHistory, .rebuildingLocalViews, .failed:
            return false
        }
    }

    private func shouldRerunBackfill(for state: AccountRestoreStoredState) -> Bool {
        if state.restoredSchemaVersion != schemaVersionProvider() {
            return true
        }
        guard let storedAppVersion = state.lastRestoreAppVersion,
              let currentAppVersion = appVersionProvider() else {
            return false
        }
        return storedAppVersion != currentAppVersion
    }

    private func setStatus(_ status: AccountRestoreStatus, uid: String) {
        userDefaults.set(status.rawValue, forKey: AccountRestoreStateStoreSupport.statusKey(for: uid))
    }

    private func setDate(_ date: Date, forKey key: String) {
        userDefaults.set(date, forKey: key)
    }

    private func date(forKey key: String) -> Date? {
        userDefaults.object(forKey: key) as? Date
    }

    private func optionalInt(forKey key: String) -> Int? {
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.integer(forKey: key)
    }

    private func removeValue(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }

    private static func emptyState(uid: String) -> AccountRestoreStoredState {
        AccountRestoreStoredState(
            uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .notStarted,
            lastStartedAt: nil,
            lastCompletedAt: nil,
            lastSuccessfulBlockingRestoreAt: nil,
            lastSuccessfulBackgroundBackfillAt: nil,
            lastFailureMessage: nil,
            restoredSchemaVersion: nil,
            lastRestoreAppVersion: nil
        )
    }
}
