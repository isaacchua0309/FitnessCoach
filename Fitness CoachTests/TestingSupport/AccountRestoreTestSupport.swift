//
//  AccountRestoreTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Shared fakes and fixtures for Phase 4 account restore tests.
//

import Foundation
@testable import Fitness_Coach

enum AccountRestoreTestSupport {

    static func makeProfile(ownerUID: String, referenceDate: Date) -> UserProfile {
        var draft = ProfileTestFixtures.sampleDraft
        draft.targets = ProfileTestFixtures.sampleTargets
        return UserProfile(
            id: UUID(),
            ownerUID: ownerUID,
            name: draft.name,
            birthDate: draft.birthDate,
            age: draft.age,
            sex: draft.sex,
            heightCm: draft.heightCm,
            currentWeightKg: draft.currentWeightKg,
            goalWeightKg: draft.goalWeightKg,
            estimatedBodyFatPercentage: draft.estimatedBodyFatPercentage,
            activityLevel: draft.activityLevel,
            trainingFrequencyPerWeek: draft.trainingFrequencyPerWeek,
            averageSteps: draft.averageSteps,
            dietPreference: draft.dietPreference,
            unitSystem: draft.unitSystem,
            targets: draft.targets,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            lastPlanUpdateReason: .onboarding
        )
    }

    static func completedBlockingSummary(
        uid: String,
        referenceDate: Date
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 1,
            foodEntriesRestored: 1,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: nil
        )
    }
}

@MainActor
final class RecordingAccountMigrationService: AccountMigrationRunning {
    private(set) var callCount = 0
    var lastUID: String?

    func runSafeBackfill(for uid: String) async throws {
        callCount += 1
        lastUID = uid
    }
}

actor SelectiveFailingAccountDataRemoteStore: AccountDataRemoteStore {

    enum FailingOperation: Hashable {
        case fetchDailyLogs
        case fetchFoodEntries
        case fetchWaterEntries
        case fetchWeightEntries
        case fetchDailyReview
        case fetchDailyLogsUpdatedSince
        case fetchFoodEntriesUpdatedSince
        case fetchWaterEntriesUpdatedSince
        case fetchWeightEntriesUpdatedSince
        case fetchDailyReviewsUpdatedSince
    }

    private let backing: InMemoryAccountDataRemoteStore
    private var failingOperations: Set<FailingOperation>
    private let failure: Error

    init(
        backing: InMemoryAccountDataRemoteStore = InMemoryAccountDataRemoteStore(),
        failingOperations: Set<FailingOperation>,
        failure: Error = URLError(.cannotConnectToHost)
    ) {
        self.backing = backing
        self.failingOperations = failingOperations
        self.failure = failure
    }

    func backingStore() -> InMemoryAccountDataRemoteStore { backing }

    private func throwIfNeeded(_ operation: FailingOperation) throws {
        if failingOperations.contains(operation) {
            throw failure
        }
    }

    func fetchDailyLog(uid: String, localDate: String) async throws -> CloudDailyLogDocument? {
        try throwIfNeeded(.fetchDailyLogs)
        return try await backing.fetchDailyLog(uid: uid, localDate: localDate)
    }

    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {
        try await backing.saveDailyLog(document, uid: uid)
    }

    func fetchDailyLogs(uid: String, from startDate: String, to endDate: String) async throws -> [CloudDailyLogDocument] {
        try throwIfNeeded(.fetchDailyLogs)
        return try await backing.fetchDailyLogs(uid: uid, from: startDate, to: endDate)
    }

    func fetchFoodEntries(uid: String, localDate: String) async throws -> [CloudFoodEntryDocument] {
        try throwIfNeeded(.fetchFoodEntries)
        return try await backing.fetchFoodEntries(uid: uid, localDate: localDate)
    }

    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String) async throws {
        try await backing.saveFoodEntry(document, uid: uid)
    }

    func deleteFoodEntry(uid: String, localDate: String, entryId: String) async throws {
        try await backing.deleteFoodEntry(uid: uid, localDate: localDate, entryId: entryId)
    }

    func fetchWaterEntries(uid: String, localDate: String) async throws -> [CloudWaterEntryDocument] {
        try throwIfNeeded(.fetchWaterEntries)
        return try await backing.fetchWaterEntries(uid: uid, localDate: localDate)
    }

    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String) async throws {
        try await backing.saveWaterEntry(document, uid: uid)
    }

    func deleteWaterEntry(uid: String, localDate: String, entryId: String) async throws {
        try await backing.deleteWaterEntry(uid: uid, localDate: localDate, entryId: entryId)
    }

    func fetchWeightEntries(
        uid: String,
        from startDate: String?,
        to endDate: String?
    ) async throws -> [CloudWeightEntryDocument] {
        try throwIfNeeded(.fetchWeightEntries)
        return try await backing.fetchWeightEntries(uid: uid, from: startDate, to: endDate)
    }

    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {
        try await backing.saveWeightEntry(document, uid: uid)
    }

    func deleteWeightEntry(uid: String, entryId: String) async throws {
        try await backing.deleteWeightEntry(uid: uid, entryId: entryId)
    }

    func fetchDailyReview(uid: String, localDate: String) async throws -> CloudDailyReviewDocument? {
        try throwIfNeeded(.fetchDailyReview)
        return try await backing.fetchDailyReview(uid: uid, localDate: localDate)
    }

    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String) async throws {
        try await backing.saveDailyReview(document, uid: uid)
    }

    func deleteDailyReview(uid: String, localDate: String) async throws {
        try await backing.deleteDailyReview(uid: uid, localDate: localDate)
    }

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? {
        try await backing.fetchSyncMetadata(uid: uid)
    }

    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        try await backing.saveSyncMetadata(document, uid: uid)
    }

    func fetchDailyLogsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyLogDocument] {
        try throwIfNeeded(.fetchDailyLogsUpdatedSince)
        return try await backing.fetchDailyLogsUpdatedSince(uid: uid, since: since, limit: limit)
    }

    func fetchFoodEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudFoodEntryDocument] {
        try throwIfNeeded(.fetchFoodEntriesUpdatedSince)
        return try await backing.fetchFoodEntriesUpdatedSince(
            uid: uid,
            since: since,
            from: startDate,
            to: endDate,
            limit: limit
        )
    }

    func fetchWaterEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudWaterEntryDocument] {
        try throwIfNeeded(.fetchWaterEntriesUpdatedSince)
        return try await backing.fetchWaterEntriesUpdatedSince(
            uid: uid,
            since: since,
            from: startDate,
            to: endDate,
            limit: limit
        )
    }

    func fetchWeightEntriesUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudWeightEntryDocument] {
        try throwIfNeeded(.fetchWeightEntriesUpdatedSince)
        return try await backing.fetchWeightEntriesUpdatedSince(uid: uid, since: since, limit: limit)
    }

    func fetchDailyReviewsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyReviewDocument] {
        try throwIfNeeded(.fetchDailyReviewsUpdatedSince)
        return try await backing.fetchDailyReviewsUpdatedSince(uid: uid, since: since, limit: limit)
    }

    func fetchCloudProfileUpdatedSince(uid: String, since: Date?) async throws -> CloudUserProfileDocument? {
        try await backing.fetchCloudProfileUpdatedSince(uid: uid, since: since)
    }
}

struct RestoreTestCloudProfileStore: CloudUserProfileStoring, @unchecked Sendable {
    var document: CloudUserProfileDocument?
    var fetchError: Error?

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        _ = uid
        if let fetchError {
            throw fetchError
        }
        return document
    }

    func save(profile: UserProfile, uid: String) async throws {
        _ = profile
        _ = uid
    }
}

final class RestoreTestNetworkChecker: AccountSyncNetworkChecking {
    var isNetworkAvailable = true
}
