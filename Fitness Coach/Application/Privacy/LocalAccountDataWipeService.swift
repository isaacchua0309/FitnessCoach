//
//  LocalAccountDataWipeService.swift
//  Fitness Coach
//
//  Forma — UID-scoped local data wipe for account deletion (Phase 6).
//
//  Deletes SwiftData rows, UID-scoped UserDefaults, health cache files, and
//  in-memory session state for one Firebase UID without touching other users.
//

import Foundation
import SwiftData

protocol LocalAccountDataWiping: AnyObject {
    func wipeLocalData(
        for uid: String,
        scope: AccountDeletionScope,
        authorization: LocalAccountDataWipeAuthorization
    ) async -> AccountDeletionSummary
}

enum LocalAccountDataWipeAuthorization: Equatable, Sendable {
    case activeSession
    case deletionInProgress(uid: String)
}

/// Stops listeners, cancels sync/restore, and blocks new scheduling before local wipe.
protocol LocalAccountDataWipeSessionPreparing: AnyObject {
    func prepareForLocalWipe(uid: String) async
}

enum LocalAccountDataWipeSupport {

    static func normalizedUID(_ uid: String) throws -> String {
        try AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    static func cacheDirectoryURL(
        for userID: String,
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let root = rootDirectory ?? defaultHealthCacheRoot(fileManager: fileManager) else {
            return nil
        }
        return root.appendingPathComponent(userID, isDirectory: true)
    }

    @discardableResult
    static func clearOnDiskHealthCache(
        for userID: String,
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let directory = cacheDirectoryURL(
            for: userID,
            rootDirectory: rootDirectory,
            fileManager: fileManager
        ) else {
            return false
        }
        guard fileManager.fileExists(atPath: directory.path) else {
            return true
        }
        do {
            try fileManager.removeItem(at: directory)
            return true
        } catch {
            return false
        }
    }

    private static func defaultHealthCacheRoot(fileManager: FileManager) -> URL? {
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("Forma", isDirectory: true)
            .appendingPathComponent("HealthCache", isDirectory: true)
    }
}

private struct LocalSwiftDataWipeCounts: Equatable {
    var localProfileDeleted = false
    var localDailyLogsDeleted = 0
    var localFoodEntriesDeleted = 0
    var localWaterEntriesDeleted = 0
    var localWeightEntriesDeleted = 0
    var localDailyReviewsDeleted = 0
    var localCoachMessagesDeleted = 0
    var localTimelineEventsDeleted = 0
    var pendingMutationsDeleted = 0
}

@MainActor
final class LocalAccountDataWipeService: LocalAccountDataWiping {

    private let store: SwiftDataStore
    private let healthCacheStore: LocalHealthCacheStore
    private let userDefaults: UserDefaults
    private let restoreStateStore: AccountRestoreStateStoring
    private let syncCursorStore: AccountSyncCursorStoring
    private let healthConsentStore: HealthSummarySyncConsentStoring
    private let healthSyncStateStore: HealthSummaryRemoteSyncStateStoring
    private let profileCloudSyncStore: ProfileCloudSyncStore
    private let healthCacheRootDirectory: URL?
    private let sessionPreparer: LocalAccountDataWipeSessionPreparing?
    private let currentSessionUIDProvider: () -> String?
    private let fileManager: FileManager
    private let clearPipelineTracer: () -> Void
    private let clearInMemoryCoachState: () -> Void
    private let clearSyncDiagnostics: () -> Void
    private let clearRestoreDiagnostics: () -> Void
    private let nowProvider: () -> Date

    init(
        store: SwiftDataStore,
        healthCacheStore: LocalHealthCacheStore,
        userDefaults: UserDefaults = .standard,
        restoreStateStore: AccountRestoreStateStoring,
        syncCursorStore: AccountSyncCursorStoring,
        healthConsentStore: HealthSummarySyncConsentStoring,
        healthSyncStateStore: HealthSummaryRemoteSyncStateStoring,
        profileCloudSyncStore: ProfileCloudSyncStore,
        healthCacheRootDirectory: URL? = nil,
        sessionPreparer: LocalAccountDataWipeSessionPreparing? = nil,
        currentSessionUIDProvider: @escaping () -> String? = { nil },
        fileManager: FileManager = .default,
        clearPipelineTracer: (() -> Void)? = nil,
        clearInMemoryCoachState: @escaping () -> Void = {},
        clearSyncDiagnostics: @escaping () -> Void = {},
        clearRestoreDiagnostics: @escaping () -> Void = {},
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.healthCacheStore = healthCacheStore
        self.userDefaults = userDefaults
        self.restoreStateStore = restoreStateStore
        self.syncCursorStore = syncCursorStore
        self.healthConsentStore = healthConsentStore
        self.healthSyncStateStore = healthSyncStateStore
        self.profileCloudSyncStore = profileCloudSyncStore
        self.healthCacheRootDirectory = healthCacheRootDirectory
        self.sessionPreparer = sessionPreparer
        self.currentSessionUIDProvider = currentSessionUIDProvider
        self.fileManager = fileManager
        self.clearPipelineTracer = clearPipelineTracer ?? { FormaPipelineTracer.clear() }
        self.clearInMemoryCoachState = clearInMemoryCoachState
        self.clearSyncDiagnostics = clearSyncDiagnostics
        self.clearRestoreDiagnostics = clearRestoreDiagnostics
        self.nowProvider = nowProvider
    }

    func wipeLocalData(
        for uid: String,
        scope: AccountDeletionScope,
        authorization: LocalAccountDataWipeAuthorization = .activeSession
    ) async -> AccountDeletionSummary {
        let startedAt = nowProvider()

        let normalizedUID: String
        do {
            normalizedUID = try LocalAccountDataWipeSupport.normalizedUID(uid)
        } catch {
            return failureSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                scope: scope,
                startedAt: startedAt,
                category: .unknown,
                message: "Local wipe could not start for this account."
            )
        }

        guard scope.wipesLocalAppData else {
            return completedSummary(
                uid: normalizedUID,
                scope: scope,
                startedAt: startedAt,
                counts: LocalSwiftDataWipeCounts(),
                localHealthCacheDeleted: false,
                localPreferencesDeleted: false
            )
        }

        guard isAuthorizedToWipe(
            targetUID: normalizedUID,
            authorization: authorization
        ) else {
            return failureSummary(
                uid: normalizedUID,
                scope: scope,
                startedAt: startedAt,
                category: .accountSwitched,
                message: "Account changed before local data could be removed."
            )
        }

        if case .activeSession = authorization {
            await sessionPreparer?.prepareForLocalWipe(uid: normalizedUID)
        }

        var swiftDataError: Error?
        var swiftCounts = LocalSwiftDataWipeCounts()
        do {
            swiftCounts = try wipeSwiftData(for: normalizedUID)
        } catch {
            swiftDataError = error
        }

        let preferencesResult = clearUIDScopedPreferences(for: normalizedUID)
        let healthCacheDeleted = clearHealthCache(for: normalizedUID)
        _ = FileFoodCorrectionMemoryStore.deleteFile(for: normalizedUID, fileManager: fileManager)
        clearInMemoryStateIfCurrentSession(matches: normalizedUID)

        if let swiftDataError {
            return partialSummary(
                uid: normalizedUID,
                scope: scope,
                startedAt: startedAt,
                counts: swiftCounts,
                localHealthCacheDeleted: healthCacheDeleted,
                localPreferencesDeleted: preferencesResult.didClearAny,
                message: "Some local data could not be removed.",
                underlying: swiftDataError
            )
        }

        if !healthCacheDeleted && LocalAccountDataWipeSupport.cacheDirectoryURL(
            for: normalizedUID,
            rootDirectory: healthCacheRootDirectory,
            fileManager: fileManager
        ).map({ fileManager.fileExists(atPath: $0.path) }) == true {
            return partialSummary(
                uid: normalizedUID,
                scope: scope,
                startedAt: startedAt,
                counts: swiftCounts,
                localHealthCacheDeleted: false,
                localPreferencesDeleted: preferencesResult.didClearAny,
                message: "Some local health cache files could not be removed.",
                underlying: nil
            )
        }

        return completedSummary(
            uid: normalizedUID,
            scope: scope,
            startedAt: startedAt,
            counts: swiftCounts,
            localHealthCacheDeleted: healthCacheDeleted,
            localPreferencesDeleted: preferencesResult.didClearAny
        )
    }

    // MARK: - SwiftData

    private func wipeSwiftData(for uid: String) throws -> LocalSwiftDataWipeCounts {
        var counts = LocalSwiftDataWipeCounts()

        counts.localFoodEntriesDeleted = try deleteOwnedSyncEntities(FoodEntryEntity.self, uid: uid)
        counts.localWaterEntriesDeleted = try deleteOwnedSyncEntities(WaterEntryEntity.self, uid: uid)
        counts.localWeightEntriesDeleted = try deleteOwnedSyncEntities(WeightEntryEntity.self, uid: uid)
        counts.localDailyReviewsDeleted = try deleteOwnedSyncEntities(DailyReviewEntity.self, uid: uid)
        counts.localDailyLogsDeleted = try deleteOwnedSyncEntities(DailyLogEntity.self, uid: uid)
        counts.localCoachMessagesDeleted = try deleteCoachMessages(uid: uid)
        counts.localTimelineEventsDeleted = try deleteCoachTimelineEvents(uid: uid)
        counts.pendingMutationsDeleted = try deleteSyncMutations(uid: uid)
        counts.localProfileDeleted = try deleteOwnedProfiles(uid: uid)

        if store.modelContext.hasChanges {
            try store.save()
        }

        return counts
    }

    private func deleteOwnedSyncEntities<T: PersistentModel & AccountDataSyncOwnable>(
        _ type: T.Type,
        uid: String
    ) throws -> Int {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == uid
            }
        )
        return try deleteFetched(descriptor)
    }

    private func deleteCoachMessages(uid: String) throws -> Int {
        let descriptor = FetchDescriptor<CoachChatTranscriptMessageEntity>(
            predicate: #Predicate { entity in
                entity.userId == uid
            }
        )
        return try deleteFetched(descriptor)
    }

    private func deleteCoachTimelineEvents(uid: String) throws -> Int {
        let descriptor = FetchDescriptor<CoachTimelineEventEntity>(
            predicate: #Predicate { entity in
                entity.userId == uid
            }
        )
        return try deleteFetched(descriptor)
    }

    private func deleteSyncMutations(uid: String) throws -> Int {
        let descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { mutation in
                mutation.ownerUID == uid
            }
        )
        return try deleteFetched(descriptor)
    }

    private func deleteOwnedProfiles(uid: String) throws -> Bool {
        let descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { profile in
                profile.ownerUID == uid
            }
        )
        return try deleteFetched(descriptor) > 0
    }

    private func deleteFetched<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        let entities = try store.fetch(descriptor)
        for entity in entities {
            store.modelContext.delete(entity)
        }
        return entities.count
    }

    // MARK: - Preferences

    private struct PreferencesWipeResult {
        let didClearAny: Bool
    }

    private func clearUIDScopedPreferences(for uid: String) -> PreferencesWipeResult {
        var didClearAny = false

        restoreStateStore.clear(uid: uid)
        didClearAny = true

        syncCursorStore.clear(uid: uid)
        didClearAny = true

        healthConsentStore.clear(for: uid)
        healthSyncStateStore.clear(for: uid)
        didClearAny = true

        if profileCloudSyncStore.lastSyncedUID == uid {
            profileCloudSyncStore.clear()
            didClearAny = true
        }

        if userDefaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey) == uid {
            userDefaults.removeObject(forKey: AccountDataNamespaceService.lastActiveUIDKey)
            didClearAny = true
        }

        return PreferencesWipeResult(didClearAny: didClearAny)
    }

    // MARK: - Health cache

    private func clearHealthCache(for uid: String) -> Bool {
        let onDiskCleared = LocalAccountDataWipeSupport.clearOnDiskHealthCache(
            for: uid,
            rootDirectory: healthCacheRootDirectory,
            fileManager: fileManager
        )

        if currentSessionUIDProvider().flatMap({ try? LocalAccountDataWipeSupport.normalizedUID($0) }) == uid {
            healthCacheStore.clearAll()
        }

        return onDiskCleared
    }

    // MARK: - In-memory

    private func clearInMemoryStateIfCurrentSession(matches uid: String) {
        guard currentSessionUIDProvider().flatMap({ try? LocalAccountDataWipeSupport.normalizedUID($0) }) == uid else {
            return
        }
        clearPipelineTracer()
        clearInMemoryCoachState()
        clearSyncDiagnostics()
        clearRestoreDiagnostics()
    }

    private func isAuthorizedToWipe(
        targetUID: String,
        authorization: LocalAccountDataWipeAuthorization
    ) -> Bool {
        switch authorization {
        case .activeSession:
            return AccountDeletionPolicy.mayDeleteData(
                for: targetUID,
                sessionUID: currentSessionUIDProvider()
            )
        case .deletionInProgress(let authorizedUID):
            guard let normalizedAuthorized = try? LocalAccountDataWipeSupport.normalizedUID(authorizedUID),
                  let normalizedTarget = try? LocalAccountDataWipeSupport.normalizedUID(targetUID) else {
                return false
            }
            return normalizedAuthorized == normalizedTarget
        }
    }

    // MARK: - Summary builders

    private func completedSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        counts: LocalSwiftDataWipeCounts,
        localHealthCacheDeleted: Bool,
        localPreferencesDeleted: Bool
    ) -> AccountDeletionSummary {
        makeSummary(
            uid: uid,
            scope: scope,
            status: .completed,
            startedAt: startedAt,
            endedAt: nowProvider(),
            counts: counts,
            localHealthCacheDeleted: localHealthCacheDeleted,
            localPreferencesDeleted: localPreferencesDeleted,
            failureCategory: nil,
            userFacingMessage: nil
        )
    }

    private func partialSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        counts: LocalSwiftDataWipeCounts,
        localHealthCacheDeleted: Bool,
        localPreferencesDeleted: Bool,
        message: String,
        underlying: Error?
    ) -> AccountDeletionSummary {
        _ = underlying
        return makeSummary(
            uid: uid,
            scope: scope,
            status: .partial,
            startedAt: startedAt,
            endedAt: nowProvider(),
            counts: counts,
            localHealthCacheDeleted: localHealthCacheDeleted,
            localPreferencesDeleted: localPreferencesDeleted,
            failureCategory: .localWipeFailed,
            userFacingMessage: message
        )
    }

    private func failureSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        category: AccountDeletionFailureCategory,
        message: String
    ) -> AccountDeletionSummary {
        makeSummary(
            uid: uid,
            scope: scope,
            status: .failed,
            startedAt: startedAt,
            endedAt: nowProvider(),
            counts: LocalSwiftDataWipeCounts(),
            localHealthCacheDeleted: false,
            localPreferencesDeleted: false,
            failureCategory: category,
            userFacingMessage: message
        )
    }

    private func makeSummary(
        uid: String,
        scope: AccountDeletionScope,
        status: AccountDeletionStatus,
        startedAt: Date,
        endedAt: Date?,
        counts: LocalSwiftDataWipeCounts,
        localHealthCacheDeleted: Bool,
        localPreferencesDeleted: Bool,
        failureCategory: AccountDeletionFailureCategory?,
        userFacingMessage: String?
    ) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: scope,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            remoteProfileDeleted: false,
            remoteDailyLogsDeleted: 0,
            remoteFoodEntriesDeleted: 0,
            remoteWaterEntriesDeleted: 0,
            remoteWeightEntriesDeleted: 0,
            remoteDailyReviewsDeleted: 0,
            remoteHealthSummariesDeleted: false,
            authAccountDeleted: false,
            localProfileDeleted: counts.localProfileDeleted,
            localDailyLogsDeleted: counts.localDailyLogsDeleted,
            localFoodEntriesDeleted: counts.localFoodEntriesDeleted,
            localWaterEntriesDeleted: counts.localWaterEntriesDeleted,
            localWeightEntriesDeleted: counts.localWeightEntriesDeleted,
            localDailyReviewsDeleted: counts.localDailyReviewsDeleted,
            localCoachMessagesDeleted: counts.localCoachMessagesDeleted,
            localTimelineEventsDeleted: counts.localTimelineEventsDeleted,
            localHealthCacheDeleted: localHealthCacheDeleted,
            localPreferencesDeleted: localPreferencesDeleted,
            pendingMutationsDeleted: counts.pendingMutationsDeleted,
            failureCategory: failureCategory,
            userFacingMessage: userFacingMessage
        )
    }
}
