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
        try await configureHarness(remoteStore: InMemoryAccountDataRemoteStore())
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

    // MARK: - Incremental pull

    func testPullsOnlyDocumentsUpdatedSinceCursor() async throws {
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

    func testPullInsertsNewRemoteFoodEntry() async throws {
        let foodID = "remote-food"
        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: referenceDate), uid: ownerUID)
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(entryId: foodID, name: "Cloud Meal", updatedAt: referenceDate),
            uid: ownerUID
        )

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledFoodEntries, 1)
        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodID)?.name, "Cloud Meal")
        XCTAssertEqual(try fetchFoodEntity(id: foodID)?.syncStatus, .synced)
    }

    func testPullUpdatesSyncedLocalFoodWhenRemoteNewer() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Old Name",
            updatedAt: referenceDate
        )
        food.syncStatus = .synced
        food.cloudId = foodID.uuidString
        try store.save()

        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: referenceDate), uid: ownerUID)
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(
                entryId: foodID.uuidString,
                name: "New Name",
                updatedAt: referenceDate.addingTimeInterval(300)
            ),
            uid: ownerUID
        )

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.name, "New Name")
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.syncStatus, .synced)
    }

    func testPullSkipsLocalPendingUpload() async throws {
        let foodID = UUID()
        let localUpdatedAt = referenceDate.addingTimeInterval(500)
        let remoteUpdatedAt = referenceDate

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

        XCTAssertEqual(summary.skippedLocalNewer, 1)
        XCTAssertEqual(summary.conflicts, 0)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.name, "Local Draft")
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.syncStatus, .pendingUpload)
    }

    func testPullAppliesRemoteFoodDeleteWhenSafe() async throws {
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

    func testPullDoesNotApplyRemoteDeleteOverPendingLocalEdit() async throws {
        let foodID = UUID()
        let localUpdatedAt = referenceDate.addingTimeInterval(300)
        let deletedAt = referenceDate.addingTimeInterval(120)

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

        var remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "Deleted Remote",
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

        XCTAssertEqual(summary.conflicts, 1)
        XCTAssertEqual(summary.status, .partial)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.name, "Local Draft")
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.syncStatus, .conflict)
        XCTAssertNil(try fetchFoodEntity(id: foodID.uuidString)?.deletedAt)
    }

    func testPullUpdatesWeightHistory() async throws {
        let weightID = UUID().uuidString
        let updatedAt = referenceDate.addingTimeInterval(180)

        var remoteWeight = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: ownerUID,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: weightID
        )
        remoteWeight.weightKg = 71.2
        remoteWeight.updatedAt = updatedAt
        try await remoteStore.saveWeightEntry(remoteWeight, uid: ownerUID)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledWeightEntries, 1)
        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(try fetchWeightEntity(id: weightID)?.weightKg, 71.2)
        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).weightEntriesLastPulledAt, updatedAt)
    }

    func testPullUpdatesDailyReview() async throws {
        let updatedAt = referenceDate.addingTimeInterval(240)
        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: referenceDate), uid: ownerUID)
        var remoteReview = FirestoreAccountDataRemoteStoreTestFixtures.dailyReview(
            userId: ownerUID,
            localDate: localDate,
            referenceDate: referenceDate
        )
        remoteReview.summaryText = "Strong recovery day"
        remoteReview.updatedAt = updatedAt
        try await remoteStore.saveDailyReview(remoteReview, uid: ownerUID)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledDailyReviews, 1)
        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(try fetchDailyReview(localDate: localDate)?.summaryText, "Strong recovery day")
        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).dailyReviewsLastPulledAt, updatedAt)
    }

    func testPullUpdatesDailyLogTotals() async throws {
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        dailyLog.syncStatus = .synced
        dailyLog.cloudId = localDate
        try store.save()

        let updatedAt = referenceDate.addingTimeInterval(420)
        var remoteDailyLog = makeDailyLogDocument(updatedAt: referenceDate)
        remoteDailyLog.caloriesConsumed = 1_120
        remoteDailyLog.proteinConsumed = 92
        remoteDailyLog.updatedAt = updatedAt
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: ownerUID)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledDailyLogs, 1)
        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(dailyLog.caloriesConsumed, 1_120)
        XCTAssertEqual(dailyLog.proteinConsumed, 92)
        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).dailyLogsLastPulledAt, updatedAt)
    }

    func testPullRejectsOwnerMismatch() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: otherUID)
        _ = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: otherUID,
            name: "Other User Meal",
            updatedAt: referenceDate
        )

        try await remoteStore.saveDailyLog(makeDailyLogDocument(updatedAt: referenceDate), uid: ownerUID)
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(
                entryId: foodID.uuidString,
                name: "Cloud Meal",
                updatedAt: referenceDate.addingTimeInterval(300)
            ),
            uid: ownerUID
        )

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.name, "Other User Meal")
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.ownerUID, otherUID)
    }

    func testPullUpdatesCursorOnlyForSuccessfulDomains() async throws {
        let updatedAt = referenceDate.addingTimeInterval(90)
        let backing = InMemoryAccountDataRemoteStore()
        try await backing.saveDailyLog(
            makeDailyLogDocument(updatedAt: updatedAt, caloriesConsumed: 640),
            uid: ownerUID
        )
        let failingRemote = SelectiveFailingAccountDataRemoteStore(
            backing: backing,
            failingOperations: [.fetchWeightEntriesUpdatedSince]
        )
        try await configureHarness(remoteStore: failingRemote)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.pulledDailyLogs, 1)
        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).dailyLogsLastPulledAt, updatedAt)
        XCTAssertNil(cursorStore.loadCursor(uid: ownerUID).weightEntriesLastPulledAt)
    }

    func testPartialFailureDoesNotAdvanceFailedDomainCursor() async throws {
        let baseline = referenceDate
        let updatedAt = referenceDate.addingTimeInterval(200)
        let weightID = UUID().uuidString

        let backing = InMemoryAccountDataRemoteStore()
        var remoteWeight = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: ownerUID,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: weightID
        )
        remoteWeight.updatedAt = updatedAt
        try await backing.saveWeightEntry(remoteWeight, uid: ownerUID)

        let failingRemote = SelectiveFailingAccountDataRemoteStore(
            backing: backing,
            failingOperations: [.fetchWeightEntriesUpdatedSince]
        )
        try await configureHarness(remoteStore: failingRemote)
        cursorStore.updateCursor(uid: ownerUID, domain: .weightEntries, date: baseline)

        let summary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.failed, 1)
        XCTAssertNil(try fetchWeightEntity(id: weightID))
        XCTAssertEqual(cursorStore.loadCursor(uid: ownerUID).weightEntriesLastPulledAt, baseline)
    }

    func testManualRefreshUsesWiderLookbackThanForeground() async throws {
        let foregroundRange = AccountIncrementalPullerSupport.dateRange(
            for: .foregroundRefresh,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let manualRange = AccountIncrementalPullerSupport.dateRange(
            for: .manualRefresh,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let foregroundDates = AccountSyncPuller.localDates(
            from: foregroundRange.start,
            to: foregroundRange.end,
            calendar: calendar
        )
        let manualDates = AccountSyncPuller.localDates(
            from: manualRange.start,
            to: manualRange.end,
            calendar: calendar
        )

        XCTAssertGreaterThan(manualDates.count, foregroundDates.count)
        XCTAssertEqual(foregroundDates.count, CrossDeviceSyncPolicy.foregroundPullLookbackDays)
        XCTAssertEqual(manualDates.count, CrossDeviceSyncPolicy.manualRefreshLookbackDays)

        let outsideForegroundDate = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -(CrossDeviceSyncPolicy.foregroundPullLookbackDays + 5), to: referenceDate)
        )
        let outsideForegroundLocalDate = CloudAccountDataDateCodec.localDateString(
            from: outsideForegroundDate,
            calendar: calendar
        )
        let foodID = "historical-food"

        try await remoteStore.saveDailyLog(
            makeDailyLogDocument(localDate: outsideForegroundLocalDate, updatedAt: referenceDate),
            uid: ownerUID
        )
        try await remoteStore.saveFoodEntry(
            makeFoodDocument(
                entryId: foodID,
                localDate: outsideForegroundLocalDate,
                name: "Historical Meal",
                updatedAt: referenceDate
            ),
            uid: ownerUID
        )

        let foregroundSummary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )
        XCTAssertEqual(foregroundSummary.pulledFoodEntries, 0)
        XCTAssertNil(try fetchFoodEntity(id: foodID))

        let manualSummary = await incrementalPuller.pullChanges(
            for: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        XCTAssertEqual(manualSummary.pulledFoodEntries, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodID)?.name, "Historical Meal")
    }

    // MARK: - Harness

    private func configureHarness(remoteStore: any AccountDataRemoteStore) async throws {
        if let defaults {
            defaults.removePersistentDomain(forName: defaults.suiteName!)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        sessionUID = ownerUID

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        if let inMemoryStore = remoteStore as? InMemoryAccountDataRemoteStore {
            self.remoteStore = inMemoryStore
        }
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

    // MARK: - Helpers

    private func makeDailyLogDocument(
        userId: String = "user-a",
        localDate: String? = nil,
        updatedAt: Date,
        caloriesConsumed: Int = 520
    ) -> CloudDailyLogDocument {
        var document = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userId,
            localDate: localDate ?? self.localDate,
            referenceDate: updatedAt
        )
        document.caloriesConsumed = caloriesConsumed
        document.updatedAt = updatedAt
        return document
    }

    private func makeFoodDocument(
        entryId: String,
        userId: String = "user-a",
        localDate: String? = nil,
        name: String,
        updatedAt: Date
    ) -> CloudFoodEntryDocument {
        var document = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userId,
            localDate: localDate ?? self.localDate,
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

    private func fetchWeightEntity(id: String) throws -> WeightEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<WeightEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchDailyReview(localDate: String) throws -> DailyReviewEntity? {
        let reviews = try store.fetch(FetchDescriptor<DailyReviewEntity>())
        return reviews.first {
            guard let date = $0.dailyLog?.date else { return false }
            return CloudAccountDataDateCodec.localDateString(from: date, calendar: calendar) == localDate
        }
    }
}
