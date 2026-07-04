//
//  AccountIncrementalPullerTests.swift
//  Fitness CoachTests
//
//  Forma — Incremental cross-device pull tests (Phase 5).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountIncrementalPullerTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate

    private var store: SwiftDataStore!
    private var remoteStore: InMemoryAccountDataRemoteStore!
    private var puller: AccountSyncPuller!
    private var cursorStore: AccountSyncCursorStore!
    private var defaults: UserDefaults!
    private var profileService: UserProfileService!
    private var profileBootstrapService: ProfileBootstrapService!
    private var profileCloudSyncStore: ProfileCloudSyncStore!
    private var dailyLogService: DailyLogService!
    private var localInspector: AccountLocalDataInspector!
    private var outbox: SwiftDataAccountSyncOutboxStore!
    private var incrementalPuller: AccountIncrementalPuller!
    private var calendar: Calendar!
    private var localDate: String!
    private var sessionUID: String!

    override func setUp() async throws {
        try await super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        sessionUID = ownerUID

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        remoteStore = InMemoryAccountDataRemoteStore()
        puller = AccountSyncPuller(
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { self.referenceDate }
        )
        defaults = UserDefaults(suiteName: "AccountIncrementalPullerTests.\(UUID().uuidString)")!
        cursorStore = AccountSyncCursorStore(userDefaults: defaults)
        profileService = UserProfileService(store: store)
        profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: defaults)
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar)
        dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider
        )
        profileBootstrapService = ProfileBootstrapService(
            userProfileService: profileService,
            cloudStore: RestoreTestCloudProfileStore(),
            cloudSyncStore: profileCloudSyncStore,
            dailyLogService: dailyLogService
        )
        outbox = SwiftDataAccountSyncOutboxStore(store: store)
        localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: outbox,
            calendar: calendar
        )
        incrementalPuller = AccountIncrementalPuller(
            remoteStore: remoteStore,
            mergePuller: puller,
            cursorStore: cursorStore,
            profileBootstrapService: profileBootstrapService,
            userProfileService: profileService,
            profileCloudSyncStore: profileCloudSyncStore,
            localInspector: localInspector,
            currentUIDProvider: { [weak self] in self?.sessionUID },
            calendar: calendar,
            nowProvider: { self.referenceDate }
        )
    }

    override func tearDown() async throws {
        incrementalPuller = nil
        localInspector = nil
        outbox = nil
        profileBootstrapService = nil
        profileCloudSyncStore = nil
        dailyLogService = nil
        profileService = nil
        cursorStore = nil
        defaults.removePersistentDomain(forName: defaults.suiteName!)
        defaults = nil
        puller = nil
        remoteStore = nil
        store = nil
        try await super.tearDown()
    }

    func testIncrementalPullInsertsOnlyDocumentsAfterCursor() async throws {
        let baseline = referenceDate
        let newer = referenceDate.addingTimeInterval(300)
        let foodOldID = "food-old"
        let foodNewID = "food-new"

        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: baseline), uid: ownerUID)
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(entryId: foodOldID, name: "Old Meal", updatedAt: baseline),
            uid: ownerUID
        )
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(entryId: foodNewID, name: "New Meal", updatedAt: newer),
            uid: ownerUID
        )

        cursorStore.updateCursor(uid: ownerUID, domain: .foodEntries, date: baseline)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledFoodEntries, 1)
        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodNewID)?.name, "New Meal")
        XCTAssertNil(try fetchFoodEntity(id: foodOldID))
        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).foodEntriesLastPulledAt, newer)
    }

    func testIncrementalPullDoesNotOverwritePendingLocalEdit() async throws {
        let foodID = UUID()
        let localUpdatedAt = referenceDate.addingTimeInterval(500)
        let remoteUpdatedAt = referenceDate.addingTimeInterval(700)

        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Local Draft",
            updatedAt: localUpdatedAt
        )
        food.syncStatus = .pendingUpload
        food.localUpdatedAt = localUpdatedAt
        try store.save()

        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: referenceDate), uid: ownerUID)
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(
                entryId: foodID.uuidString,
                name: "Remote Edit",
                updatedAt: remoteUpdatedAt
            ),
            uid: ownerUID
        )

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.conflicts, 1)
        XCTAssertEqual(summary.status, .partial)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.name, "Local Draft")
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.syncStatus, .conflict)
    }

    func testIncrementalPullAppliesRemoteDeleteTombstone() async throws {
        let foodID = UUID()
        let deletedAt = referenceDate.addingTimeInterval(120)
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Synced Meal",
            updatedAt: referenceDate
        )
        food.syncStatus = .synced
        food.cloudId = foodID.uuidString
        food.lastSyncedAt = referenceDate
        try store.save()

        var remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "Synced Meal",
            updatedAt: deletedAt
        )
        remoteFood.deletedAt = deletedAt
        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: referenceDate), uid: ownerUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: ownerUID)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.deleted, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.deletedAt, deletedAt)
    }

    func testIncrementalPullNeverMergesCrossUserDocuments() async throws {
        let foreignFoodID = "foreign-food"
        try await remoteStore.saveDailyLog(
            makeDailyLogDocument(userId: otherUID, updatedAt: referenceDate),
            uid: ownerUID
        )
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(
                entryId: foreignFoodID,
                userId: otherUID,
                name: "Foreign Meal",
                updatedAt: referenceDate.addingTimeInterval(60)
            ),
            uid: ownerUID
        )

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledFoodEntries, 0)
        XCTAssertEqual(summary.inserted, 0)
        XCTAssertNil(try fetchFoodEntity(id: foreignFoodID))
    }

    func testUserAAndUserBCursorsAreIsolated() async throws {
        let timeA = referenceDate
        let timeB = referenceDate.addingTimeInterval(600)

        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: timeA), uid: ownerUID)
        try await remoteStore.saveDailyLog(
            makeDailyLogDocument(userId: otherUID, updatedAt: timeB),
            uid: otherUID
        )

        _ = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )
        sessionUID = otherUID
        _ = await incrementalPuller.pullChanges(
            for: otherUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).dailyLogsLastPulledAt, timeA)
        XCTAssertEqual(cursorStore.loadCursor(uid: otherUID).dailyLogsLastPulledAt, timeB)
    }

    func testIncrementalPullUpdatesForegroundRefreshTimestamp() async throws {
        _ = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).lastForegroundRefreshAt, referenceDate)
    }

    func testIncrementalPullMergesNewerRemoteProfileWhenLocalIsSynced() async throws {
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: ownerUID)
        profileCloudSyncStore.markSynced(uid: ownerUID, updatedAt: referenceDate)

        var remote = ProfileTestFixtures.cloudDocument(referenceDate: referenceDate)
        remote.targets.calorieTarget = 2_050
        remote.updatedAt = referenceDate.addingTimeInterval(600)
        try await remoteStore.seedCloudProfile(remote, uid: ownerUID)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertTrue(summary.pulledProfile)
        XCTAssertEqual(try profileService.getCurrentProfile()?.targets.calorieTarget, 2_050)
        _ = try dailyLogService.getOrCreateLog(for: referenceDate)
        XCTAssertEqual(try dailyLogService.getTodayLog().targets.calorieTarget, 2_050)
    }

    func testIncrementalPullDoesNotOverwriteUnsyncedLocalProfileEdit() async throws {
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: ownerUID)
        profileCloudSyncStore.markSynced(uid: ownerUID, updatedAt: referenceDate)
        _ = try profileService.updateTargets(
            UserTargets(
                calorieTarget: 2_200,
                proteinTarget: 140,
                carbTarget: 180,
                fatTarget: 60,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: 0.4,
                aggressiveness: .moderate
            )
        )

        var remote = ProfileTestFixtures.cloudDocument(referenceDate: referenceDate)
        remote.targets.calorieTarget = 1_600
        remote.updatedAt = referenceDate.addingTimeInterval(900)
        try await remoteStore.seedCloudProfile(remote, uid: ownerUID)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertFalse(summary.pulledProfile)
        XCTAssertEqual(summary.conflicts, 1)
        XCTAssertEqual(try profileService.getCurrentProfile()?.targets.calorieTarget, 2_200)
    }

    func testIncrementalPullCancelsProfileMergeAfterAccountSwitch() async throws {
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: ownerUID)
        profileCloudSyncStore.markSynced(uid: ownerUID, updatedAt: referenceDate)

        var remote = ProfileTestFixtures.cloudDocument(referenceDate: referenceDate)
        remote.targets.calorieTarget = 1_900
        remote.updatedAt = referenceDate.addingTimeInterval(600)
        try await remoteStore.seedCloudProfile(remote, uid: ownerUID)

        sessionUID = otherUID
        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.status, .cancelled)
        XCTAssertFalse(summary.pulledProfile)
        XCTAssertEqual(try profileService.getCurrentProfile()?.targets.calorieTarget, 1_800)
    }

    // MARK: - Helpers

    private func makeDailyLogDocument(
        userId: String = "user-a",
        updatedAt: Date
    ) -> CloudDailyLogDocument {
        var document = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userId,
            localDate: localDate,
            referenceDate: updatedAt
        )
        document.updatedAt = updatedAt
        return document
    }

    private func makeFoodDocument(
        entryId: String,
        userId: String = "user-a",
        name: String,
        updatedAt: Date
    ) -> CloudFoodEntryDocument {
        var document = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userId,
            localDate: localDate,
            referenceDate: updatedAt,
            entryId: entryId
        )
        document.name = name
        document.updatedAt = updatedAt
        return document
    }

    @discardableResult
    private func seedDailyLog(ownerUID: String) throws -> DailyLogEntity {
        let entity = DailyLogEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: referenceDate,
            weightKg: nil,
            calorieTarget: 2_000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.5,
            aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: 0,
            proteinConsumed: 0,
            carbsConsumed: 0,
            fatConsumed: 0,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        try store.insert(entity)
        return entity
    }

    @discardableResult
    private func seedFood(
        id: UUID,
        dailyLog: DailyLogEntity,
        ownerUID: String,
        name: String,
        updatedAt: Date
    ) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: id,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: updatedAt
        )
        food.dailyLog = dailyLog
        try store.insert(food)
        return food
    }

    private func fetchFoodEntity(id: String) throws -> FoodEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }
}
