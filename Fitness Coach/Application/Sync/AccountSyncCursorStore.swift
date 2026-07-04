//
//  AccountSyncCursorStore.swift
//  Fitness Coach
//
//  Forma — Per-UID incremental cross-device sync cursors (Phase 5).
//
//  Stores last successful pull timestamps per data domain only.
//  Never persists food names, weights, review text, or other personal content.
//

import Foundation

enum AccountSyncCursorDomain: String, Codable, CaseIterable, Sendable {
    case profile
    case dailyLogs
    case foodEntries
    case waterEntries
    case weightEntries
    case dailyReviews
}

struct AccountSyncCursor: Codable, Equatable, Sendable {
    let uid: String
    let profileLastPulledAt: Date?
    let dailyLogsLastPulledAt: Date?
    let foodEntriesLastPulledAt: Date?
    let waterEntriesLastPulledAt: Date?
    let weightEntriesLastPulledAt: Date?
    let dailyReviewsLastPulledAt: Date?
    let lastForegroundRefreshAt: Date?
    let lastManualRefreshAt: Date?
}

protocol AccountSyncCursorStoring: Sendable {
    func loadCursor(uid: String) -> AccountSyncCursor
    func updateCursor(uid: String, domain: AccountSyncCursorDomain, date: Date)
    func updateForegroundRefresh(uid: String, date: Date)
    func updateManualRefresh(uid: String, date: Date)
    func clear(uid: String)
}

enum AccountSyncCursorStoreSupport {

    static let keyPrefix = "forma.crossDeviceSync"

    static func normalizedUID(_ uid: String) -> String? {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func profileLastPulledAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).profileLastPulledAt"
    }

    static func dailyLogsLastPulledAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).dailyLogsLastPulledAt"
    }

    static func foodEntriesLastPulledAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).foodEntriesLastPulledAt"
    }

    static func waterEntriesLastPulledAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).waterEntriesLastPulledAt"
    }

    static func weightEntriesLastPulledAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).weightEntriesLastPulledAt"
    }

    static func dailyReviewsLastPulledAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).dailyReviewsLastPulledAt"
    }

    static func lastForegroundRefreshAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastForegroundRefreshAt"
    }

    static func lastManualRefreshAtKey(for uid: String) -> String {
        "\(keyPrefix).\(uid).lastManualRefreshAt"
    }

    static func domainKey(for domain: AccountSyncCursorDomain, uid: String) -> String {
        switch domain {
        case .profile:
            return profileLastPulledAtKey(for: uid)
        case .dailyLogs:
            return dailyLogsLastPulledAtKey(for: uid)
        case .foodEntries:
            return foodEntriesLastPulledAtKey(for: uid)
        case .waterEntries:
            return waterEntriesLastPulledAtKey(for: uid)
        case .weightEntries:
            return weightEntriesLastPulledAtKey(for: uid)
        case .dailyReviews:
            return dailyReviewsLastPulledAtKey(for: uid)
        }
    }

    static func allKeys(for uid: String) -> [String] {
        [
            profileLastPulledAtKey(for: uid),
            dailyLogsLastPulledAtKey(for: uid),
            foodEntriesLastPulledAtKey(for: uid),
            waterEntriesLastPulledAtKey(for: uid),
            weightEntriesLastPulledAtKey(for: uid),
            dailyReviewsLastPulledAtKey(for: uid),
            lastForegroundRefreshAtKey(for: uid),
            lastManualRefreshAtKey(for: uid)
        ]
    }
}

struct AccountSyncCursorStore: AccountSyncCursorStoring {

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadCursor(uid: String) -> AccountSyncCursor {
        guard let normalizedUID = AccountSyncCursorStoreSupport.normalizedUID(uid) else {
            return emptyCursor(uid: uid.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return AccountSyncCursor(
            uid: normalizedUID,
            profileLastPulledAt: date(for: AccountSyncCursorStoreSupport.profileLastPulledAtKey(for: normalizedUID)),
            dailyLogsLastPulledAt: date(for: AccountSyncCursorStoreSupport.dailyLogsLastPulledAtKey(for: normalizedUID)),
            foodEntriesLastPulledAt: date(for: AccountSyncCursorStoreSupport.foodEntriesLastPulledAtKey(for: normalizedUID)),
            waterEntriesLastPulledAt: date(for: AccountSyncCursorStoreSupport.waterEntriesLastPulledAtKey(for: normalizedUID)),
            weightEntriesLastPulledAt: date(for: AccountSyncCursorStoreSupport.weightEntriesLastPulledAtKey(for: normalizedUID)),
            dailyReviewsLastPulledAt: date(for: AccountSyncCursorStoreSupport.dailyReviewsLastPulledAtKey(for: normalizedUID)),
            lastForegroundRefreshAt: date(for: AccountSyncCursorStoreSupport.lastForegroundRefreshAtKey(for: normalizedUID)),
            lastManualRefreshAt: date(for: AccountSyncCursorStoreSupport.lastManualRefreshAtKey(for: normalizedUID))
        )
    }

    func updateCursor(uid: String, domain: AccountSyncCursorDomain, date: Date) {
        guard let normalizedUID = AccountSyncCursorStoreSupport.normalizedUID(uid) else { return }
        let key = AccountSyncCursorStoreSupport.domainKey(for: domain, uid: normalizedUID)
        setMonotonicDate(date, forKey: key)
    }

    func updateForegroundRefresh(uid: String, date: Date) {
        guard let normalizedUID = AccountSyncCursorStoreSupport.normalizedUID(uid) else { return }
        let key = AccountSyncCursorStoreSupport.lastForegroundRefreshAtKey(for: normalizedUID)
        setMonotonicDate(date, forKey: key)
    }

    func updateManualRefresh(uid: String, date: Date) {
        guard let normalizedUID = AccountSyncCursorStoreSupport.normalizedUID(uid) else { return }
        let key = AccountSyncCursorStoreSupport.lastManualRefreshAtKey(for: normalizedUID)
        setMonotonicDate(date, forKey: key)
    }

    func clear(uid: String) {
        guard let normalizedUID = AccountSyncCursorStoreSupport.normalizedUID(uid) else { return }
        for key in AccountSyncCursorStoreSupport.allKeys(for: normalizedUID) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Private

    private func emptyCursor(uid: String) -> AccountSyncCursor {
        AccountSyncCursor(
            uid: uid,
            profileLastPulledAt: nil,
            dailyLogsLastPulledAt: nil,
            foodEntriesLastPulledAt: nil,
            waterEntriesLastPulledAt: nil,
            weightEntriesLastPulledAt: nil,
            dailyReviewsLastPulledAt: nil,
            lastForegroundRefreshAt: nil,
            lastManualRefreshAt: nil
        )
    }

    private func date(for key: String) -> Date? {
        userDefaults.object(forKey: key) as? Date
    }

    /// Keeps cursors monotonic when callers report successful domain merges out of order.
    private func setMonotonicDate(_ date: Date, forKey key: String) {
        if let existing = userDefaults.object(forKey: key) as? Date, existing >= date {
            return
        }
        userDefaults.set(date, forKey: key)
    }
}
