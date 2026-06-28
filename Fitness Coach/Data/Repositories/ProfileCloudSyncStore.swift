//
//  ProfileCloudSyncStore.swift
//  Fitness Coach
//
//  Forma — Tracks which Firebase UID last received a confirmed cloud profile upload.
//

import Foundation

/// Persists cloud sync metadata without SwiftData schema changes.
struct ProfileCloudSyncStore: Sendable {

    private let userDefaults: UserDefaults

    private let lastSyncedUIDKey = "forma.profileCloudSync.lastSyncedUID"
    private let lastSyncedProfileUpdatedAtKey = "forma.profileCloudSync.lastSyncedProfileUpdatedAt"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastSyncedUID: String? {
        userDefaults.string(forKey: lastSyncedUIDKey)
    }

    var lastSyncedProfileUpdatedAt: Date? {
        userDefaults.object(forKey: lastSyncedProfileUpdatedAtKey) as? Date
    }

    func isSyncedForUID(_ uid: String) -> Bool {
        lastSyncedUID == uid
    }

    func markSynced(uid: String, updatedAt: Date) {
        userDefaults.set(uid, forKey: lastSyncedUIDKey)
        userDefaults.set(updatedAt, forKey: lastSyncedProfileUpdatedAtKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: lastSyncedUIDKey)
        userDefaults.removeObject(forKey: lastSyncedProfileUpdatedAtKey)
    }
}
