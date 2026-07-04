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

    private var sessionUID: String?
    private var defaults: UserDefaults!
    private var healthCacheRoot: URL!
    private var wipeService: LocalAccountDataWipeService!
    private var store: SwiftDataStore!
    private var profileService: UserProfileService!
    private var foodLogService: FoodLogService!
    private var restoreStateStore: AccountRestoreStateStore!
    private var syncCursorStore: AccountSyncCursorStore!

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
            profileCloudSyncStore: ProfileCloudSyncStore(userDefaults: defaults),
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
        defaults.removePersistentDomain(forName: defaults.suiteName!)
        defaults = nil
        try? FileManager.default.removeItem(at: healthCacheRoot)
        healthCacheRoot = nil
        sessionUID = nil
        try await super.tearDown()
    }

    func testWipeDeletesAllCurrentUIDLocalData() async throws {
        try seedUserAData()
        restoreStateStore.markSkipped(uid: userA, reason: .afterSignIn, now: referenceDate)
        syncCursorStore.updateForegroundRefresh(uid: userA, date: referenceDate)
        defaults.set(userA, forKey: AccountDataNamespaceService.lastActiveUIDKey)
        try writeHealthCacheMarker(for: userA)

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.localProfileDeleted)
        XCTAssertGreaterThan(summary.localFoodEntriesDeleted, 0)
        XCTAssertTrue(summary.localHealthCacheDeleted)
        XCTAssertTrue(summary.localPreferencesDeleted)
        XCTAssertNil(try profileService.getCurrentProfile())
        XCTAssertTrue(try store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)
        XCTAssertNil(defaults.string(forKey: AccountDataNamespaceService.lastActiveUIDKey))
        XCTAssertNil(defaults.string(forKey: AccountRestoreStateStoreSupport.statusKey(for: userA)))
        XCTAssertFalse(healthCacheDirectoryExists(for: userA))
    }

    func testWipeDoesNotDeleteOtherUIDDataOnSameDevice() async throws {
        try seedUserAData()
        try insertOwnedFood(name: "User B Meal", calories: 510, ownerUID: userB)
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userB)
        sessionUID = userA

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(try ownedFoodCount(for: userA), 0)
        XCTAssertEqual(try ownedFoodCount(for: userB), 1)
        XCTAssertNotNil(try profileFor(ownerUID: userB))
        XCTAssertNil(try profileFor(ownerUID: userA))
    }

    func testSecondWipeIsIdempotent() async throws {
        try seedUserAData()

        let first = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)
        let second = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(second.status, .completed)
        XCTAssertEqual(try ownedFoodCount(for: userA), 0)
    }

    func testWipeRejectsMismatchedSessionUID() async throws {
        try seedUserAData()
        sessionUID = userB

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .failed)
        XCTAssertEqual(summary.failureCategory, .accountSwitched)
        XCTAssertEqual(try ownedFoodCount(for: userA), 1)
    }

    func testRemoteOnlyScopeSkipsLocalWipe() async throws {
        try seedUserAData()

        let summary = await wipeService.wipeLocalData(for: userA, scope: .remoteAccountDataOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(try ownedFoodCount(for: userA), 1)
        XCTAssertFalse(summary.didDeleteAnyLocalData)
    }

    func testWipeDeletesCoachAndSyncMutationRowsForUID() async throws {
        try seedUserAData()
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
            AccountSyncMutationEntity(
                id: "mutation-1",
                ownerUID: userA,
                entityType: .foodEntry,
                entityId: UUID().uuidString,
                localDate: "2026-07-04",
                operation: .upsert,
                payloadVersion: 1,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        )
        try store.save()

        let summary = await wipeService.wipeLocalData(for: userA, scope: .localDeviceOnly)

        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(summary.localCoachMessagesDeleted, 1)
        XCTAssertEqual(summary.pendingMutationsDeleted, 1)
        XCTAssertEqual(try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).count, 0)
        XCTAssertEqual(try store.fetch(FetchDescriptor<AccountSyncMutationEntity>()).count, 0)
    }

    // MARK: - Helpers

    private func seedUserAData() throws {
        sessionUID = userA
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userA)
        _ = try foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User A Meal", calories: 420),
            for: referenceDate
        )
    }

    private func seedUserBData() throws {
        sessionUID = userB
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: userB)
        _ = try foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "User B Meal", calories: 510),
            for: referenceDate
        )
    }

    private func insertOwnedFood(name: String, calories: Int, ownerUID: String) throws {
        let dailyLogId = UUID()
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLogId,
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

    private func ownedFoodCount(for uid: String) throws -> Int {
        let descriptor = FetchDescriptor<FoodEntryEntity>(
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
