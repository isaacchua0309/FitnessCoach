//
//  LocalAccountDataWipeServiceTests.swift
//  Fitness CoachTests
//
//  Forma — UID-scoped local wipe isolation tests (Phase 6).
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class LocalAccountDataWipeServiceTests: XCTestCase {

    private let userA = "user-a"
    private let userB = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate
    private let localDate = "2026-07-04"

    private var sessionUID: String?
    private var defaults: UserDefaults!
    private var healthCacheRoot: URL!
    private var wipeService: LocalAccountDataWipeService!
    private var store: SwiftDataStore!
    private var profileService: UserProfileService!
    private var foodLogService: FoodLogService!
    private var restoreStateStore: AccountRestoreStateStore!
    private var syncCursorStore: AccountSyncCursorStore!
    private var profileCloudSyncStore: ProfileCloudSyncStore!

    override func setUp() async throws {
        try await super.setUp()
        sessionUID = userA
        defaults = UserDefaults(suiteName: "LocalAccountDataWipeServiceTests.\(UUID().uuidString)")!
        healthCacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalAccountDataWipeServiceTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: healthCacheRoot, withIntermediateDirectories: true)

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate)
        profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let uidProvider = { [weak self] in self?.sessionUID }
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            currentUIDProvider: uidProvider
        )
        foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            currentUIDProvider: uidProvider
        )

        restoreStateStore = AccountRestoreStateStore(userDefaults: defaults)
        syncCursorStore = AccountSyncCursorStore(userDefaults: defaults)
        profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: defaults)

        let authUIDCache = AuthUIDCache()
        authUIDCache.update(uid: sessionUID)
        let healthCacheStore = LocalHealthCacheStore(
            userProvider: authUIDCache,
            rootDirectory: healthCacheRoot
        )

        wipeService = LocalAccountDataWipeService(
            store: store,
            healthCacheStore: healthCacheStore,
            userDefaults: defaults,
            restoreStateStore: restoreStateStore,
            syncCursorStore: syncCursorStore,
            healthConsentStore: UserDefaultsHealthSummarySyncConsentStore(userDefaults: defaults),
            healthSyncStateStore: UserDefaultsHealthSummaryRemoteSyncStateStore(userDefaults: defaults),
            profileCloudSyncStore: profileCloudSyncStore,
            healthCacheRootDirectory: healthCacheRoot,
            currentSessionUIDProvider: { [weak self] in self?.sessionUID },
            fileManager: .default,
            clearPipelineTracer: {},
            clearInMemoryCoachState: {},
            clearSyncDiagnostics: {},
            clearRestoreDiagnostics: {}
        )
    }

    override func tearDown() async throws {
        wipeService = nil
        foodLogService = nil
        profileService = nil
        store = nil
        syncCursorStore = nil
        restoreStateStore = nil
        profileCloudSyncStore = nil
        defaults.removePersistentDomain(forName: defaults.suiteName!)
        defaults = nil
        try? FileManager.default.removeItem(at: healthCacheRoot)
        healthCacheRoot = nil
        sessionUID = nil
        try await super.tearDown()
    }

    func testWipeDeletesCurrentUserFoodWaterWeight() async throws {
        try seedUserAFoodWaterWeight()

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertGreaterThan(summary.localFoodEntriesDeleted, 0)
        XCTAssertGreaterThan(summary.localWaterEntriesDeleted, 0)
        XCTAssertGreaterThan(summary.localWeightEntriesDeleted, 0)
        XCTAssertEqual(try ownedEntityCount(FoodEntryEntity.self, uid: userA), 0)
        XCTAssertEqual(try ownedEntityCount(WaterEntryEntity.self, uid: userA), 0)
        XCTAssertEqual(try ownedEntityCount(WeightEntryEntity.self, uid: userA), 0)
    }

    func testWipeDeletesCurrentUserDailyLogsAndReviews() async throws {
        try seedUserADailyLogAndReview()

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertGreaterThan(summary.localDailyLogsDeleted, 0)
        XCTAssertGreaterThan(summary.localDailyReviewsDeleted, 0)
        XCTAssertEqual(try ownedEntityCount(DailyLogEntity.self, uid: userA), 0)
        XCTAssertEqual(try ownedEntityCount(DailyReviewEntity.self, uid: userA), 0)
    }

    func testWipeDeletesCurrentUserCoachMessagesAndTimeline() async throws {
        try seedUserACoachData()

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertGreaterThan(summary.localCoachMessagesDeleted, 0)
        XCTAssertGreaterThan(summary.localTimelineEventsDeleted, 0)
        XCTAssertEqual(try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).count, 0)
        XCTAssertEqual(try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()).count, 0)
    }

    func testWipeDeletesCurrentUserPendingMutations() async throws {
        try seedUserAPendingMutation()

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertGreaterThan(summary.pendingMutationsDeleted, 0)
        XCTAssertEqual(try store.fetch(FetchDescriptor<AccountSyncMutationEntity>()).count, 0)
    }

    func testWipeDeletesCurrentUserHealthCache() async throws {
        try writeHealthCacheMarker(for: userA)

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.localHealthCacheDeleted)
        XCTAssertFalse(healthCacheDirectoryExists(for: userA))
    }

    func testWipeDeletesCurrentUserRestoreAndSyncMetadata() async throws {
        restoreStateStore.markSkipped(uid: userA, reason: .afterSignIn, now: referenceDate)
        syncCursorStore.updateForegroundRefresh(uid: userA, date: referenceDate)
        profileCloudSyncStore.markSynced(uid: userA, updatedAt: referenceDate)
        defaults.set(userA, forKey: AccountDataNamespaceService.lastActiveUIDKey)

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.localPreferencesDeleted)
        XCTAssertNil(defaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey))
        XCTAssertNil(defaults.string(forKey: AccountRestoreStateStoreSupport.statusKey(for: userA)))
        XCTAssertFalse(profileCloudSyncStore.isSyncedForUID(userA))
    }

    func testWipeDoesNotDeleteOtherUserData() async throws {
        try seedUserAFoodWaterWeight()
        try insertOwnedFood(name: "User B Meal", calories: 510, ownerUID: userB)
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userB)
        sessionUID = userA

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(try ownedEntityCount(FoodEntryEntity.self, uid: userA), 0)
        XCTAssertEqual(try ownedEntityCount(FoodEntryEntity.self, uid: userB), 1)
        XCTAssertNotNil(try profileFor(ownerUID: userB))
        XCTAssertNil(try profileFor(ownerUID: userA))
    }

    func testWipeIsIdempotent() async throws {
        try seedUserAFoodWaterWeight()

        let first = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)
        let second = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(second.status, .completed)
        XCTAssertEqual(try ownedEntityCount(FoodEntryEntity.self, uid: userA), 0)
    }

    // MARK: - Helpers

    private func seedUserAFoodWaterWeight() throws {
        sessionUID = userA
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userA)
        _ = try foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Meal", calories: 420),
            for: referenceDate
        )
        let dailyLogId = try store.fetch(FetchDescriptor<DailyLogEntity>()).first?.id ?? UUID()
        store.modelContext.insert(
            WaterEntryEntity(
                id: UUID(),
                ownerUID: userA,
                dailyLogId: dailyLogId,
                amountMl: 250,
                createdAt: referenceDate
            )
        )
        store.modelContext.insert(
            WeightEntryEntity(
                id: UUID(),
                ownerUID: userA,
                date: referenceDate,
                weightKg: 68.2,
                note: nil,
                createdAt: referenceDate
            )
        )
        try store.save()
    }

    private func seedUserADailyLogAndReview() throws {
        sessionUID = userA
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userA)
        _ = try foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Meal", calories: 420),
            for: referenceDate
        )
        let dailyLogId = try store.fetch(FetchDescriptor<DailyLogEntity>()).first?.id ?? UUID()
        store.modelContext.insert(
            DailyReviewEntity(
                id: UUID(),
                ownerUID: userA,
                dailyLogId: dailyLogId,
                summaryText: "Solid day",
                caloriesSummary: "On target",
                proteinSummary: "High",
                hydrationSummary: "Good",
                workoutSummary: nil,
                weightSummary: nil,
                tomorrowRecommendation: "Repeat",
                createdAt: referenceDate
            )
        )
        try store.save()
    }

    private func seedUserACoachData() throws {
        sessionUID = userA
        store.modelContext.insert(
            CoachChatTranscriptMessageEntity(
                id: UUID(),
                userId: userA,
                roleRawValue: "user",
                text: "hello",
                createdAt: referenceDate,
                relatedDailyLogId: nil,
                relatedEntryId: nil,
                hasImageAttachment: false,
                imageKindRaw: nil,
                imageSourceRaw: nil,
                thumbnailJPEG: nil,
                fullImageJPEG: nil,
                originalImageByteSize: nil,
                photoSessionID: nil,
                relatedUserMessageID: nil,
                photoAnalysisLinkKindRaw: nil,
                structuredContentJSON: nil,
                updatedAt: referenceDate
            )
        )
        store.modelContext.insert(
            CoachTimelineEventEntity(
                id: UUID(),
                userId: userA,
                eventTypeRaw: "meal_logged",
                sourceRaw: "manual",
                statusRaw: "completed",
                confidenceRaw: "high",
                sourceAttributionRaw: nil,
                utcCreatedAt: referenceDate,
                localCreatedAt: referenceDate.ISO8601Format(),
                localDate: localDate,
                timezoneIdentifier: "America/Los_Angeles",
                summary: "Logged meal",
                payloadJSON: "{}",
                linkedEntryId: nil,
                linkedMessageId: nil,
                supersedesEventId: nil,
                schemaVersion: 1,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        )
        try store.save()
    }

    private func seedUserAPendingMutation() throws {
        sessionUID = userA
        store.modelContext.insert(
            AccountSyncMutationEntity(
                id: "mutation-1",
                ownerUID: userA,
                entityType: .foodEntry,
                entityId: UUID().uuidString,
                localDate: localDate,
                operation: .upsert,
                payloadVersion: 1,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        )
        try store.save()
    }

    private func insertOwnedFood(name: String, calories: Int, ownerUID: String) throws {
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: calories,
            protein: 20,
            carbs: 30,
            fat: 10,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        store.modelContext.insert(food)
        try store.save()
    }

    private func ownedEntityCount<T: PersistentModel>(
        _ type: T.Type,
        uid: String
    ) throws -> Int where T: AccountDataSyncOwnable {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == uid
            }
        )
        return try store.fetch(descriptor).count
    }

    private func profileFor(ownerUID: String) throws -> UserProfileEntity? {
        let descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { profile in
                profile.ownerUID == ownerUID
            }
        )
        return try store.fetch(descriptor).first
    }

    private func writeHealthCacheMarker(for uid: String) throws {
        let directory = healthCacheRoot.appendingPathComponent(uid, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("metadata.json")
        try Data("{}".utf8).write(to: marker)
    }

    private func healthCacheDirectoryExists(for uid: String) -> Bool {
        let directory = healthCacheRoot.appendingPathComponent(uid, isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.path)
    }
}
