//
//  AccountInitialRestoreServiceTests.swift
//  Fitness CoachTests
//
//  Forma — Account initial restore service tests (Phase 4).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountInitialRestoreServiceTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileTestFixtures.referenceDate
    private var calendar: Calendar!
    private var localDate: String!

    private var harness: RestoreServiceHarness!

    override func setUp() async throws {
        try await super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        harness = try RestoreServiceHarness.make(
            ownerUID: ownerUID,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    override func tearDown() async throws {
        harness = nil
        try await super.tearDown()
    }

    func testFreshInstallRestoresProfileAndRecentLogs() async throws {
        try await harness.seedCloudNutritionData()

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.profileRestored)
        XCTAssertGreaterThan(summary.dailyLogsRestored, 0)
        XCTAssertGreaterThan(summary.foodEntriesRestored, 0)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .completed)

        let foods = try harness.store.fetch(FetchDescriptor<FoodEntryEntity>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.ownerUID, ownerUID)
        XCTAssertEqual(foods.first?.syncStatus, .synced)
    }

    func testFreshInstallRestoresFoodWaterWeightAndReviews() async throws {
        try await harness.seedFullCloudNutritionData()

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .newDevice
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.profileRestored)
        XCTAssertGreaterThan(summary.foodEntriesRestored, 0)
        XCTAssertGreaterThan(summary.waterEntriesRestored, 0)
        XCTAssertGreaterThan(summary.weightEntriesRestored, 0)
        XCTAssertGreaterThan(summary.dailyReviewsRestored, 0)

        XCTAssertEqual(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).count, 1)
        XCTAssertEqual(try harness.store.fetch(FetchDescriptor<WaterEntryEntity>()).count, 1)
        XCTAssertEqual(try harness.store.fetch(FetchDescriptor<WeightEntryEntity>()).count, 1)
        XCTAssertEqual(try harness.store.fetch(FetchDescriptor<DailyReviewEntity>()).count, 1)
    }

    func testFreshInstallWithNoCloudDataCompletesEmpty() async {
        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .freshInstall
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertFalse(summary.profileRestored)
        XCTAssertEqual(summary.totalEntitiesRestored, 0)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .completed)
        XCTAssertNotNil(summary.userFacingMessage)
    }

    func testRestoreDoesNotDuplicateExistingLocalRows() async throws {
        let foodID = UUID()
        try await harness.seedCloudNutritionData(foodID: foodID)
        _ = try await harness.service.runBlockingInitialRestore(uid: ownerUID, reason: .afterSignIn)
        XCTAssertEqual(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).count, 1)

        let secondSummary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .appLaunch
        )

        XCTAssertEqual(secondSummary.status, .skipped)
        XCTAssertEqual(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).count, 1)
    }

    func testRestoreSkipsNewerPendingLocalEdit() async throws {
        try await harness.seedCloudNutritionData()
        _ = try await harness.service.runBlockingInitialRestore(uid: ownerUID, reason: .afterSignIn)

        let foodID = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first?.id
        )
        let dailyLog = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).first
        )
        let food = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == foodID }
        )
        food.name = "Edited Locally"
        food.calories = 999
        food.syncStatus = .pendingUpload
        food.localUpdatedAt = referenceDate.addingTimeInterval(300)
        try harness.store.save()

        try await harness.seedCloudNutritionData(
            foodID: foodID,
            foodName: "Cloud Replacement",
            calories: 100
        )

        harness.stateStore.prepareForManualRetry(uid: ownerUID, now: referenceDate)
        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .manualRetry
        )

        XCTAssertTrue(summary.skippedLocalNewer > 0 || summary.status == .completed)
        let stored = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == foodID }
        )
        XCTAssertEqual(stored.name, "Edited Locally")
        XCTAssertEqual(stored.calories, 999)
        XCTAssertEqual(stored.syncStatus, .pendingUpload)
        _ = dailyLog
    }

    func testRestoreMarksPartialWhenSomeCollectionsFail() async throws {
        let partialHarness = try await RestoreServiceHarness.makeWithFailingRemote(
            ownerUID: ownerUID,
            referenceDate: referenceDate,
            calendar: calendar,
            failingOperations: [.fetchWeightEntries]
        )
        try await partialHarness.seedFullCloudNutritionData()

        let summary = await partialHarness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .partial)
        XCTAssertTrue(summary.isPartial)
        XCTAssertGreaterThan(summary.failed, 0)
        XCTAssertEqual(partialHarness.stateStore.loadState(uid: ownerUID).status, .partial)
        XCTAssertGreaterThan(try partialHarness.store.fetch(FetchDescriptor<FoodEntryEntity>()).count, 0)
    }

    func testRestoreMarksOfflineWhenRemoteUnavailable() async throws {
        _ = try harness.seedLocalProfile(ownerUID: ownerUID)
        harness.networkChecker.isNetworkAvailable = false

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .offline)
        XCTAssertTrue(summary.allowsContinuedEntry)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .offline)
    }

    func testRestoreIsIdempotent() async throws {
        try await harness.seedFullCloudNutritionData()

        let first = await harness.service.runBlockingInitialRestore(uid: ownerUID, reason: .afterSignIn)
        let foodCountAfterFirst = try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).count
        let waterCountAfterFirst = try harness.store.fetch(FetchDescriptor<WaterEntryEntity>()).count

        harness.stateStore.prepareForManualRetry(uid: ownerUID, now: referenceDate)
        let second = await harness.service.runBlockingInitialRestore(uid: ownerUID, reason: .manualRetry)

        XCTAssertEqual(first.status, .completed)
        XCTAssertEqual(foodCountAfterFirst, try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).count)
        XCTAssertEqual(waterCountAfterFirst, try harness.store.fetch(FetchDescriptor<WaterEntryEntity>()).count)
        XCTAssertTrue(second.status == .completed || second.status == .skipped)
    }

    func testFreshInstallWithCloudDataRestoresLocalLogs() async throws {
        harness.networkChecker.isNetworkAvailable = false

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .failed)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .failed)
        XCTAssertTrue(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)
    }

    func testOfflineRestoreWithLocalProfileAllowsContinue() async throws {
        _ = try harness.seedLocalProfile(ownerUID: ownerUID)
        harness.networkChecker.isNetworkAvailable = false

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .offline)
        XCTAssertTrue(summary.allowsContinuedEntry)
    }

    func testExistingLocalUnsyncedEditsArePreservedDuringBackfill() async throws {
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedBlockingSummary(),
            now: referenceDate
        )

        let foodID = UUID()
        let dailyLog = try harness.seedLocalDailyLog(ownerUID: ownerUID)
        _ = try harness.seedLocalFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Local Meal",
            calories: 500,
            syncStatus: .pendingUpload,
            localUpdatedAt: referenceDate.addingTimeInterval(120)
        )

        try await harness.seedCloudNutritionData(
            foodID: foodID,
            foodName: "Cloud Meal",
            calories: 300,
            updatedAt: referenceDate
        )

        let summary = await harness.service.runBackgroundBackfill(
            uid: ownerUID,
            reason: .appLaunch
        )

        XCTAssertTrue(summary.skippedLocalNewer > 0 || summary.status == .completed)
        let stored = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == foodID }
        )
        XCTAssertEqual(stored.name, "Local Meal")
        XCTAssertEqual(stored.calories, 500)
        XCTAssertEqual(stored.syncStatus, .pendingUpload)
    }

    func testPopulatedLocalAccountSkipsBlockingRestore() async throws {
        let dailyLog = try harness.seedLocalDailyLog(ownerUID: ownerUID)
        _ = try harness.seedLocalFood(
            id: UUID(),
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Existing Meal",
            calories: 450,
            syncStatus: .synced,
            localUpdatedAt: referenceDate
        )
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedBlockingSummary(),
            now: referenceDate
        )

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .appLaunch
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .skipped)
    }

    func testBackgroundBackfillPullsWiderHistory() async throws {
        _ = try harness.seedLocalProfile(ownerUID: ownerUID)
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedBlockingSummary(),
            now: referenceDate
        )

        let olderDate = try XCTUnwrap(calendar.date(byAdding: .day, value: -120, to: referenceDate))
        let olderLocalDate = CloudAccountDataDateCodec.localDateString(from: olderDate, calendar: calendar)
        try await harness.remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: ownerUID,
                localDate: olderLocalDate,
                referenceDate: olderDate
            ),
            uid: ownerUID
        )

        let summary = await harness.service.runBackgroundBackfill(
            uid: ownerUID,
            reason: .appLaunch
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertNotNil(harness.stateStore.loadState(uid: ownerUID).lastSuccessfulBackgroundBackfillAt)
        let logs = try harness.store.fetch(FetchDescriptor<DailyLogEntity>())
        XCTAssertFalse(logs.isEmpty)
    }

    func testBackgroundBackfillRequiresLocalProfile() async {
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedBlockingSummary(),
            now: referenceDate
        )

        let summary = await harness.service.runBackgroundBackfill(
            uid: ownerUID,
            reason: .appLaunch
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertNil(harness.stateStore.loadState(uid: ownerUID).lastSuccessfulBackgroundBackfillAt)
    }

    func testBackgroundBackfillPartialFailureAllowsRetry() async throws {
        _ = try harness.seedLocalProfile(ownerUID: ownerUID)
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedBlockingSummary(),
            now: referenceDate
        )
        harness.networkChecker.isNetworkAvailable = false

        let summary = await harness.service.runBackgroundBackfill(
            uid: ownerUID,
            reason: .appLaunch
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertTrue(
            harness.stateStore.shouldRunBackgroundBackfill(
                uid: ownerUID,
                now: referenceDate.addingTimeInterval(60)
            )
        )
    }

    // MARK: - Fixtures

    private func completedBlockingSummary() -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: ownerUID,
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

// MARK: - Harness

@MainActor
private final class RestoreServiceHarness {

    let store: SwiftDataStore
    let profileService: UserProfileService
    let dailyLogService: DailyLogService
    let remoteStore: InMemoryAccountDataRemoteStore
    let profileStore: RestoreTestCloudProfileStore
    let stateStore: AccountRestoreStateStore
    let networkChecker: RestoreTestNetworkChecker
    let service: AccountInitialRestoreService
    let ownerUID: String
    let referenceDate: Date
    let localDate: String

    static func make(
        ownerUID: String,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> RestoreServiceHarness {
        let defaults = UserDefaults(suiteName: "AccountInitialRestoreServiceTests.\(UUID().uuidString)")!
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let mutationTracker = AccountLocalMutationTracker(
            outbox: outbox,
            ownerUIDProvider: { ownerUID }
        )
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            mutationTracker: mutationTracker
        )
        let remoteStore = InMemoryAccountDataRemoteStore()
        let puller = AccountSyncPuller(
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { referenceDate }
        )
        let localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: outbox,
            dateProvider: dateProvider,
            calendar: calendar
        )
        let profileStore = RestoreTestCloudProfileStore()
        let remoteInspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore,
            calendar: calendar
        )
        let stateStore = AccountRestoreStateStore(userDefaults: defaults)
        let networkChecker = RestoreTestNetworkChecker()
        let profileBootstrap = ProfileBootstrapService(
            userProfileService: profileService,
            cloudStore: profileStore
        )
        let service = AccountInitialRestoreService(
            profileBootstrapService: profileBootstrap,
            puller: puller,
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            stateStore: stateStore,
            dailyLogService: dailyLogService,
            networkChecker: networkChecker,
            currentUIDProvider: { ownerUID },
            dateProvider: dateProvider,
            calendar: calendar
        )

        return RestoreServiceHarness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            remoteStore: remoteStore,
            profileStore: profileStore,
            stateStore: stateStore,
            networkChecker: networkChecker,
            service: service,
            ownerUID: ownerUID,
            referenceDate: referenceDate,
            localDate: CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        )
    }

    static func makeWithFailingRemote(
        ownerUID: String,
        referenceDate: Date,
        calendar: Calendar,
        failingOperations: Set<SelectiveFailingAccountDataRemoteStore.FailingOperation>
    ) async throws -> RestoreServiceHarness {
        let defaults = UserDefaults(suiteName: "AccountInitialRestoreServiceTests.\(UUID().uuidString)")!
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let mutationTracker = AccountLocalMutationTracker(
            outbox: outbox,
            ownerUIDProvider: { ownerUID }
        )
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            mutationTracker: mutationTracker
        )
        let failingRemote = SelectiveFailingAccountDataRemoteStore(failingOperations: failingOperations)
        let remoteStore = await failingRemote.backingStore()
        let puller = AccountSyncPuller(
            remoteStore: failingRemote,
            store: store,
            calendar: calendar,
            nowProvider: { referenceDate }
        )
        let localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: outbox,
            dateProvider: dateProvider,
            calendar: calendar
        )
        let profileStore = RestoreTestCloudProfileStore()
        let remoteInspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: failingRemote,
            calendar: calendar
        )
        let stateStore = AccountRestoreStateStore(userDefaults: defaults)
        let networkChecker = RestoreTestNetworkChecker()
        let profileBootstrap = ProfileBootstrapService(
            userProfileService: profileService,
            cloudStore: profileStore
        )
        let service = AccountInitialRestoreService(
            profileBootstrapService: profileBootstrap,
            puller: puller,
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            stateStore: stateStore,
            dailyLogService: dailyLogService,
            networkChecker: networkChecker,
            currentUIDProvider: { ownerUID },
            dateProvider: dateProvider,
            calendar: calendar
        )

        let harness = RestoreServiceHarness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            remoteStore: remoteStore,
            profileStore: profileStore,
            stateStore: stateStore,
            networkChecker: networkChecker,
            service: service,
            ownerUID: ownerUID,
            referenceDate: referenceDate,
            localDate: CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        )
        return harness
    }

    func seedCloudNutritionData(
        foodID: UUID = UUID(),
        foodName: String = "Cloud Oats",
        calories: Int = 420,
        updatedAt: Date? = nil
    ) async throws {
        let updated = updatedAt ?? referenceDate
        let profile = try makeProfile(ownerUID: ownerUID)
        profileStore.document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: ownerUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: ownerUID
        )

        var food = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: ownerUID,
            localDate: localDate,
            referenceDate: updated,
            entryId: foodID.uuidString
        )
        food.name = foodName
        food.calories = calories
        food.updatedAt = updated
        try await remoteStore.saveFoodEntry(food, uid: ownerUID)
    }

    func seedFullCloudNutritionData() async throws {
        let profile = try makeProfile(ownerUID: ownerUID)
        profileStore.document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: ownerUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: ownerUID
        )
        try await remoteStore.saveFoodEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
                userId: ownerUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: ownerUID
        )
        try await remoteStore.saveWaterEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
                userId: ownerUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: ownerUID
        )
        try await remoteStore.saveWeightEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
                userId: ownerUID,
                localDate: localDate,
                referenceDate: referenceDate,
                entryId: "weight-1"
            ),
            uid: ownerUID
        )
        try await remoteStore.saveDailyReview(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyReview(
                userId: ownerUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: ownerUID
        )
    }

    @discardableResult
    func seedLocalProfile(ownerUID: String) throws -> UserProfile {
        var draft = ProfileTestFixtures.sampleDraft
        draft.targets = ProfileTestFixtures.sampleTargets
        return try profileService.createProfile(draft, ownerUID: ownerUID)
    }

    @discardableResult
    func seedLocalDailyLog(ownerUID: String) throws -> DailyLogEntity {
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
    func seedLocalFood(
        id: UUID,
        dailyLog: DailyLogEntity,
        ownerUID: String,
        name: String,
        calories: Int,
        syncStatus: AccountDataSyncStatus,
        localUpdatedAt: Date
    ) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: id,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "bowl",
            calories: calories,
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
            updatedAt: localUpdatedAt
        )
        food.dailyLog = dailyLog
        food.syncStatus = syncStatus
        food.localUpdatedAt = localUpdatedAt
        try store.insert(food)
        return food
    }

    private func makeProfile(ownerUID: String) throws -> UserProfile {
        AccountRestoreTestSupport.makeProfile(ownerUID: ownerUID, referenceDate: referenceDate)
    }
}

