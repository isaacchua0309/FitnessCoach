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

    func testFreshInstallWithCloudDataRestoresLocalLogs() async throws {
        try await harness.seedCloudNutritionData()

        let summary = await harness.service.runBlockingInitialRestore(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.profileRestored)
        XCTAssertGreaterThan(summary.foodEntriesRestored, 0)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .completed)

        let foods = try harness.store.fetch(FetchDescriptor<FoodEntryEntity>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?.ownerUID, ownerUID)
        XCTAssertEqual(foods.first?.syncStatus, .synced)
    }

    func testFreshInstallWithNoCloudDataCompletesCleanly() async {
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

    func testOfflineRestoreWithoutProfileOrLocalDataReturnsFailed() async {
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
}

private final class RestoreTestNetworkChecker: AccountSyncNetworkChecking {
    var isNetworkAvailable = true
}

private struct RestoreTestCloudProfileStore: CloudUserProfileStoring, @unchecked Sendable {
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
