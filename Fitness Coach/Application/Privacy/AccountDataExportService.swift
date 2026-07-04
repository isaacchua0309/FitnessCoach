//
//  AccountDataExportService.swift
//  Fitness Coach
//
//  Forma — Builds JSON account data exports for user-initiated download (Phase 6).
//

import Foundation
import SwiftData

protocol AccountDataExporting: AnyObject {
    func buildExportBundle(for uid: String) async throws -> AccountDataExportBundle
    func writeExportFile(for uid: String) async throws -> URL
}

enum AccountDataExportSupport {

    static let exportDirectoryName = "FormaAccountExports"
    static let exportFilenamePrefix = "forma-account-export"

    static func normalizedUID(_ uid: String) throws -> String {
        try AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    static func privacySafeUIDPrefix(_ uid: String) -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "account" }
        return String(trimmed.prefix(8))
    }
}

@MainActor
final class AccountDataExportService: AccountDataExporting {

    private let store: SwiftDataStore
    private let accountSyncOutboxStore: AccountSyncOutboxStore
    private let profileCloudSyncStore: ProfileCloudSyncStore
    private let accountSyncCursorStore: AccountSyncCursorStoring
    private let accountRestoreStateStore: AccountRestoreStateStoring
    private let currentSessionUIDProvider: () -> String?
    private let isExportEnabled: () -> Bool
    private let fileManager: FileManager
    private let nowProvider: () -> Date
    private let jsonEncoder: JSONEncoder

    init(
        store: SwiftDataStore,
        accountSyncOutboxStore: AccountSyncOutboxStore,
        profileCloudSyncStore: ProfileCloudSyncStore,
        accountSyncCursorStore: AccountSyncCursorStoring,
        accountRestoreStateStore: AccountRestoreStateStoring,
        currentSessionUIDProvider: @escaping () -> String?,
        isExportEnabled: @escaping () -> Bool = { AccountDataExportPolicy.isEnabled },
        fileManager: FileManager = .default,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.accountSyncOutboxStore = accountSyncOutboxStore
        self.profileCloudSyncStore = profileCloudSyncStore
        self.accountSyncCursorStore = accountSyncCursorStore
        self.accountRestoreStateStore = accountRestoreStateStore
        self.currentSessionUIDProvider = currentSessionUIDProvider
        self.isExportEnabled = isExportEnabled
        self.fileManager = fileManager
        self.nowProvider = nowProvider

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
    }

    func buildExportBundle(for uid: String) async throws -> AccountDataExportBundle {
        guard isExportEnabled() else {
            throw AccountDataExportError.featureDisabled
        }

        let normalizedUID = try AccountDataExportSupport.normalizedUID(uid)
        guard AccountDataExportPolicy.mayExportData(
            for: normalizedUID,
            sessionUID: currentSessionUIDProvider()
        ) else {
            throw AccountDataExportError.uidMismatch
        }

        guard currentSessionUIDProvider() != nil else {
            throw AccountDataExportError.unauthenticated
        }

        let dailyLogEntities = try fetchOwnedEntities(DailyLogEntity.self, uid: normalizedUID)
            .filter(AccountDataSyncReadFilter.isVisible)
        let allowedDailyLogIDs = Set(dailyLogEntities.map(\.id))

        let profile = try fetchOwnedProfile(uid: normalizedUID).map {
            AccountDataExportMapping.exportedProfile(from: $0.toModel())
        }

        let dailyLogs = dailyLogEntities
            .map { $0.toModel() }
            .sorted { $0.date < $1.date }
            .map(AccountDataExportMapping.exportedDailyLog)

        let foodEntries = try fetchOwnedEntities(FoodEntryEntity.self, uid: normalizedUID)
            .compactMap { AccountDataExportMapping.exportedFoodEntry(from: $0, allowedDailyLogIDs: allowedDailyLogIDs) }
            .sorted { $0.createdAt < $1.createdAt }

        let waterEntries = try fetchOwnedEntities(WaterEntryEntity.self, uid: normalizedUID)
            .compactMap { AccountDataExportMapping.exportedWaterEntry(from: $0, allowedDailyLogIDs: allowedDailyLogIDs) }
            .sorted { $0.createdAt < $1.createdAt }

        let weightEntries = try fetchOwnedEntities(WeightEntryEntity.self, uid: normalizedUID)
            .compactMap(AccountDataExportMapping.exportedWeightEntry)
            .sorted { $0.date < $1.date }

        let dailyReviews = try fetchOwnedEntities(DailyReviewEntity.self, uid: normalizedUID)
            .compactMap { AccountDataExportMapping.exportedDailyReview(from: $0, allowedDailyLogIDs: allowedDailyLogIDs) }
            .sorted { $0.createdAt < $1.createdAt }

        let mutationCounts = try await accountSyncOutboxStore.countActiveMutations(ownerUID: normalizedUID)
        let cursor = accountSyncCursorStore.loadCursor(uid: normalizedUID)
        let restoreState = accountRestoreStateStore.loadState(uid: normalizedUID)

        return AccountDataExportBundle(
            exportedAt: nowProvider(),
            uid: normalizedUID,
            profile: profile,
            dailyLogs: dailyLogs,
            foodEntries: foodEntries,
            waterEntries: waterEntries,
            weightEntries: weightEntries,
            dailyReviews: dailyReviews,
            syncMetadata: AccountDataExportMapping.exportedSyncMetadata(
                pendingUploadCount: mutationCounts.pending,
                failedUploadCount: mutationCounts.failed,
                profileCloudSyncStore: profileCloudSyncStore,
                uid: normalizedUID,
                cursor: cursor,
                restoreState: restoreState
            )
        )
    }

    func writeExportFile(for uid: String) async throws -> URL {
        let bundle = try await buildExportBundle(for: uid)
        let data: Data
        do {
            data = try jsonEncoder.encode(bundle)
        } catch {
            throw AccountDataExportError.encodingFailed
        }

        let directory = try exportDirectory()
        let filename = "\(AccountDataExportSupport.exportFilenamePrefix)-\(AccountDataExportSupport.privacySafeUIDPrefix(bundle.uid)).json"
        let fileURL = directory.appendingPathComponent(filename, isDirectory: false)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw AccountDataExportError.exportDirectoryUnavailable
        }

        return fileURL
    }

    // MARK: - Private

    private func exportDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(AccountDataExportSupport.exportDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) {
            return directory
        }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            throw AccountDataExportError.exportDirectoryUnavailable
        }
    }

    private func fetchOwnedProfile(uid: String) throws -> UserProfileEntity? {
        var descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { profile in
                profile.ownerUID == uid
            }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func fetchOwnedEntities<T: PersistentModel>(
        _ type: T.Type,
        uid: String
    ) throws -> [T] where T: AccountDataSyncOwnable {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == uid
            }
        )
        return try store.fetch(descriptor)
    }
}

#if DEBUG
@MainActor
final class InMemoryAccountDataExportService: AccountDataExporting {

    var configuredBundle: AccountDataExportBundle?
    var configuredError: AccountDataExportError?
    var configuredFileURL: URL?
    private(set) var buildCallCount = 0
    private(set) var writeCallCount = 0

    func buildExportBundle(for uid: String) async throws -> AccountDataExportBundle {
        buildCallCount += 1
        if let configuredError { throw configuredError }
        guard let configuredBundle else {
            throw AccountDataExportError.encodingFailed
        }
        return configuredBundle
    }

    func writeExportFile(for uid: String) async throws -> URL {
        writeCallCount += 1
        if let configuredError { throw configuredError }
        if let configuredFileURL { return configuredFileURL }
        _ = try await buildExportBundle(for: uid)
        return URL(fileURLWithPath: "/tmp/forma-account-export.json")
    }
}
#endif
