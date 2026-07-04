//
//  AccountDataNamespaceService.swift
//  Fitness Coach
//
//  Forma — Prepares the local SwiftData namespace when the active Firebase UID changes.
//

import Foundation
import SwiftData

@MainActor
final class AccountDataNamespaceService {

    private let store: SwiftDataStore
    private let migrationService: AccountMigrationService
    private let lastActiveUIDStore: LastActiveAccountUIDStore

    init(
        store: SwiftDataStore,
        migrationService: AccountMigrationService,
        lastActiveUIDStore: LastActiveAccountUIDStore = LastActiveAccountUIDStore()
    ) {
        self.store = store
        self.migrationService = migrationService
        self.lastActiveUIDStore = lastActiveUIDStore
    }

    /// Ensures reads for `newUID` never include another account's local rows.
    func prepareForUID(_ newUID: String, isFreshSignIn: Bool) throws {
        let previousUID = lastActiveUIDStore.lastActiveUID

        if FormaAbTest.Auth.quarantinesForeignUserDataOnAccountSwitch,
           isFreshSignIn,
           let previousUID,
           previousUID != newUID {
            try quarantineRowsNotOwnedBy(newUID)
        }

        try migrationService.backfillUnownedRows(sessionUID: newUID)
        lastActiveUIDStore.lastActiveUID = newUID
    }

    func recordSignedOut() {
        lastActiveUIDStore.lastActiveUID = nil
    }

    private func quarantineRowsNotOwnedBy(_ uid: String) throws {
        var didChange = false

        for entity in try store.fetch(FetchDescriptor<DailyLogEntity>()) {
            guard entity.ownerUID != uid else { continue }
            try store.delete(entity)
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<FoodEntryEntity>()) {
            guard entity.ownerUID != uid else { continue }
            try store.delete(entity)
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<WaterEntryEntity>()) {
            guard entity.ownerUID != uid else { continue }
            try store.delete(entity)
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<WeightEntryEntity>()) {
            guard entity.ownerUID != uid else { continue }
            try store.delete(entity)
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<DailyReviewEntity>()) {
            guard entity.ownerUID != uid else { continue }
            try store.delete(entity)
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()) {
            guard entity.userId == uid else {
                try store.delete(entity)
                didChange = true
                continue
            }
        }
        for entity in try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()) {
            guard entity.userId == uid else {
                try store.delete(entity)
                didChange = true
                continue
            }
        }

        if didChange {
            try store.save()
        }
    }
}

// MARK: - Last active UID

struct LastActiveAccountUIDStore {
    private let userDefaults: UserDefaults
    private let key = "forma.accountPersistence.lastActiveUID"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastActiveUID: String? {
        get { userDefaults.string(forKey: key) }
        nonmutating set {
            if let newValue {
                userDefaults.set(newValue, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}
