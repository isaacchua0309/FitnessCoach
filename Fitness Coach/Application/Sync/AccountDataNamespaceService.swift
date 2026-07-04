//
//  AccountDataNamespaceService.swift
//  Fitness Coach
//
//  Forma — UID namespace preparation for signed-in account restore (Phase 4).
//

import Foundation
import SwiftData

protocol AccountDataNamespacePreparing: AnyObject {
    @discardableResult
    func prepareForSignedInUID(_ uid: String) async -> Bool
}

enum AccountDataNamespaceServiceSupport {
    static let lastActiveUIDKey = "forma.accountNamespace.lastActiveUID"
}

@MainActor
final class AccountDataNamespaceService: AccountDataNamespacePreparing {

    private let store: SwiftDataStore
    private let healthCacheStore: LocalHealthCacheStore
    private let userDefaults: UserDefaults
    private let syncCoordinator: AccountSyncCoordinating?

    init(
        store: SwiftDataStore,
        healthCacheStore: LocalHealthCacheStore,
        userDefaults: UserDefaults = .standard,
        syncCoordinator: AccountSyncCoordinating? = nil
    ) {
        self.store = store
        self.healthCacheStore = healthCacheStore
        self.userDefaults = userDefaults
        self.syncCoordinator = syncCoordinator
    }

    @discardableResult
    func prepareForSignedInUID(_ uid: String) async -> Bool {
        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return false
        }

        let previousUID = userDefaults.string(forKey: AccountDataNamespaceServiceSupport.lastActiveUIDKey)
        if previousUID == normalizedUID {
            return true
        }

        syncCoordinator?.cancelPendingWork()

        do {
            try quarantineForeignOwnedData(excluding: normalizedUID)
            if previousUID != nil {
                healthCacheStore.clearAll()
            }
            userDefaults.set(normalizedUID, forKey: AccountDataNamespaceServiceSupport.lastActiveUIDKey)
            return true
        } catch {
            AccountRestoreLogger.error(
                "namespace_prepare_failed",
                fields: ["uid": normalizedUID],
                underlying: error
            )
            return false
        }
    }

    private func quarantineForeignOwnedData(excluding uid: String) throws {
        try deleteEntities(
            DailyLogEntity.self,
            excluding: uid
        )
        try deleteEntities(
            FoodEntryEntity.self,
            excluding: uid
        )
        try deleteEntities(
            WaterEntryEntity.self,
            excluding: uid
        )
        try deleteEntities(
            WeightEntryEntity.self,
            excluding: uid
        )
        try deleteEntities(
            DailyReviewEntity.self,
            excluding: uid
        )
        try deleteForeignProfiles(excluding: uid)
        try store.save()
    }

    private func deleteEntities<T: PersistentModel & AccountDataSyncOwnable>(
        _ type: T.Type,
        excluding uid: String
    ) throws {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID != nil && entity.ownerUID != uid
            }
        )
        for entity in try store.fetch(descriptor) {
            store.modelContext.delete(entity)
        }
    }

    private func deleteForeignProfiles(excluding uid: String) throws {
        let descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { profile in
                profile.ownerUID != nil && profile.ownerUID != uid
            }
        )
        for profile in try store.fetch(descriptor) {
            store.modelContext.delete(profile)
        }
    }
}
