//
//  AccountRestoreCoordinatorTests.swift
//  Fitness CoachTests
//
//  Forma — Account restore coordinator tests (Phase 4).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountRestoreCoordinatorTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"
    private let referenceDate = ProfileFixtures.referenceDate

    private var harness: RestoreCoordinatorHarness!

    override func setUp() async throws {
        try await super.setUp()
        harness = try RestoreCoordinatorHarness.make(
            ownerUID: ownerUID,
            referenceDate: referenceDate
        )
    }

    override func tearDown() async throws {
        harness = nil
        try await super.tearDown()
    }

    func testPrepareAfterSignInRunsBlockingRestoreForEmptyLocalStore() async throws {
        harness.restoreEnabled = true
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(harness.initialRestore.blockingCallCount, 1)
        XCTAssertEqual(try harness.foodCount(), 1)
    }

    func testPrepareAfterSignInSkipsBlockingRestoreForPopulatedStore() async throws {
        harness.restoreEnabled = true
        let dailyLog = try harness.seedLocalDailyLog(ownerUID: ownerUID)
        _ = try harness.seedLocalFood(dailyLog: dailyLog)
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedSummary(),
            now: referenceDate
        )
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertEqual(harness.initialRestore.blockingCallCount, 0)
    }

    func testPrepareAfterSignInRunsSafeBackfillBeforeRestore() async throws {
        harness.restoreEnabled = true
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(harness.migrationService.callCount, 1)
        XCTAssertEqual(harness.migrationService.lastUID, ownerUID)
        XCTAssertEqual(summary.status, .completed)
    }

    func testAccountSwitchIgnoresOldRestoreResult() async throws {
        harness.restoreEnabled = true
        harness.initialRestore.blockingUIDProvider = { [weak harness] in
            harness?.currentUID = self.otherUID
            return self.ownerUID
        }
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertEqual(summary.userFacingMessage, AccountRestoreCoordinatorSupport.accountSwitchedMessage)
        XCTAssertEqual(try harness.foodCount(), 0)
    }

    func testRetryRestoreRunsManualRetry() async throws {
        harness.restoreEnabled = true
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedSummary(),
            now: referenceDate
        )
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.retryRestore(uid: ownerUID)

        XCTAssertEqual(harness.initialRestore.blockingCallCount, 1)
        XCTAssertNotEqual(summary.status, .skipped)
        XCTAssertEqual(summary.mode, .blockingInitial)
    }

    func testBackgroundBackfillRunsAfterBlockingRestore() async throws {
        harness.restoreEnabled = true
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertTrue(summary.allowsContinuedEntry)
        let backfillRan = await AsyncTestSupport.waitUntilWallClock(timeout: 0.3) {
            harness.initialRestore.backgroundCallCount == 1
        }
        XCTAssertTrue(backfillRan)
        XCTAssertEqual(harness.initialRestore.backgroundCallCount, 1)
    }

    func testPrepareAccountAfterSignInRunsBlockingRestoreWhenCloudDataExists() async throws {
        harness.restoreEnabled = true
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(harness.initialRestore.blockingCallCount, 1)
        XCTAssertEqual(try harness.foodCount(), 1)
    }

    func testPrepareAccountAfterSignInSkipsWhenRestoreDisabled() async {
        harness.restoreEnabled = false

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertEqual(harness.initialRestore.blockingCallCount, 0)
        XCTAssertEqual(harness.syncCoordinator.uploadCallCount, 0)
    }

    func testPrepareAccountOnAppLaunchReturnsNilWhenNoWorkNeeded() async {
        harness.restoreEnabled = true
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedSummary(),
            now: referenceDate
        )

        let summary = await harness.coordinator.prepareAccountOnAppLaunch(uid: ownerUID)

        XCTAssertNil(summary)
        XCTAssertEqual(harness.initialRestore.blockingCallCount, 0)
    }

    func testRetryRestoreForcesBlockingRun() async throws {
        harness.restoreEnabled = true
        harness.stateStore.markCompleted(
            uid: ownerUID,
            summary: completedSummary(),
            now: referenceDate
        )
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.retryRestore(uid: ownerUID)

        XCTAssertEqual(harness.initialRestore.blockingCallCount, 1)
        XCTAssertNotEqual(summary.status, .skipped)
    }

    func testConcurrentRestoreIsRejected() async throws {
        harness.restoreEnabled = true
        harness.initialRestore.blockingDelayNanoseconds = 200_000_000
        try await harness.seedCloudNutritionData()

        async let first = harness.coordinator.prepareAccountAfterSignIn(uid: ownerUID, reason: .afterSignIn)
        async let second = harness.coordinator.prepareAccountAfterSignIn(uid: ownerUID, reason: .afterSignIn)
        let results = await [first, second]

        XCTAssertTrue(results.contains { $0.userFacingMessage == AccountRestoreCoordinatorSupport.concurrentRestoreMessage })
        XCTAssertEqual(harness.initialRestore.blockingCallCount, 1)
    }

    func testAccountSwitchDuringRestoreReturnsSkippedSummary() async throws {
        harness.restoreEnabled = true
        harness.initialRestore.blockingUIDProvider = { [weak harness] in
            harness?.currentUID = self.otherUID
            return self.ownerUID
        }
        try await harness.seedCloudNutritionData()

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .skipped)
        XCTAssertEqual(summary.userFacingMessage, AccountRestoreCoordinatorSupport.accountSwitchedMessage)
    }

    func testNamespaceServiceQuarantinesForeignOwnedRows() async throws {
        let foreignLog = try harness.seedLocalDailyLog(ownerUID: otherUID)
        _ = foreignLog
        let ownLog = try harness.seedLocalDailyLog(ownerUID: ownerUID)

        _ = await harness.namespaceService.prepareForSignedInUID(ownerUID)

        let logs = try harness.store.fetch(FetchDescriptor<DailyLogEntity>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.id, ownLog.id)
    }

    func testPermissionFailureDoesNotWriteForeignUIDData() async throws {
        harness.restoreEnabled = true
        harness.remoteInspector.failure = .permissionDenied

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: ownerUID,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .failed)
        XCTAssertEqual(harness.stateStore.loadState(uid: ownerUID).status, .failed)
        XCTAssertTrue(try harness.foodCount() == 0)
    }

    private func completedSummary() -> AccountRestoreSummary {
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
private final class RestoreCoordinatorHarness {

    let store: SwiftDataStore
    let profileService: UserProfileService
    let remoteStore: InMemoryAccountDataRemoteStore
    let profileStore: RestoreCoordinatorProfileStore
    let stateStore: AccountRestoreStateStore
    let namespaceService: AccountDataNamespaceService
    let migrationService: RecordingAccountMigrationService
    let initialRestore: RecordingInitialRestoreService
    let syncCoordinator: RecordingSyncCoordinator
    let remoteInspector: StubRemoteInspector
    let coordinator: AccountRestoreCoordinator
    let currentUIDBox: CurrentUIDBox
    var restoreEnabled: Bool {
        get { RestoreCoordinatorFeatureGate.isRestoreEnabled }
        set { RestoreCoordinatorFeatureGate.isRestoreEnabled = newValue }
    }

    var currentUID: String {
        get { currentUIDBox.uid }
        set { currentUIDBox.uid = newValue }
    }

    static func make(ownerUID: String, referenceDate: Date) throws -> RestoreCoordinatorHarness {
        let defaults = UserDefaults(suiteName: "AccountRestoreCoordinatorTests.\(UUID().uuidString)")!
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let remoteStore = InMemoryAccountDataRemoteStore()
        let profileStore = RestoreCoordinatorProfileStore()
        let stateStore = AccountRestoreStateStore(userDefaults: defaults)
        let healthCache = LocalHealthCacheStore()
        let syncCoordinator = RecordingSyncCoordinator()
        let namespaceService = AccountDataNamespaceService(
            store: store,
            healthCacheStore: healthCache,
            userDefaults: defaults,
            syncCoordinator: syncCoordinator
        )
        let migrationService = RecordingAccountMigrationService()
        let localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: SwiftDataAccountSyncOutboxStore(store: store),
            dateProvider: dateProvider
        )
        let remoteInspector = StubRemoteInspector()
        let initialRestore = RecordingInitialRestoreService(referenceDate: referenceDate)
        let currentUIDBox = CurrentUIDBox(uid: ownerUID)
        initialRestore.currentUIDProvider = { currentUIDBox.uid }
        let coordinator = AccountRestoreCoordinator(
            namespaceService: namespaceService,
            migrationService: migrationService,
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            initialRestoreService: initialRestore,
            stateStore: stateStore,
            syncCoordinator: syncCoordinator,
            currentUIDProvider: { currentUIDBox.uid },
            restoreEnabledProvider: { RestoreCoordinatorFeatureGate.isRestoreEnabled },
            dateProvider: dateProvider
        )

        return RestoreCoordinatorHarness(
            store: store,
            profileService: profileService,
            remoteStore: remoteStore,
            profileStore: profileStore,
            stateStore: stateStore,
            namespaceService: namespaceService,
            migrationService: migrationService,
            initialRestore: initialRestore,
            syncCoordinator: syncCoordinator,
            remoteInspector: remoteInspector,
            coordinator: coordinator,
            currentUIDBox: currentUIDBox
        )
    }

    @discardableResult
    func seedLocalFood(dailyLog: DailyLogEntity) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Existing Meal",
            quantity: 1,
            unit: "bowl",
            calories: 450,
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
            updatedAt: referenceDate
        )
        food.dailyLog = dailyLog
        food.syncStatus = .synced
        food.localUpdatedAt = referenceDate
        try store.insert(food)
        return food
    }

    func seedCloudNutritionData() async throws {
        let profile = AccountRestoreTestSupport.makeProfile(ownerUID: currentUID, referenceDate: referenceDate)
        profileStore.document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        remoteInspector.hasCloudProfile = true
        remoteInspector.hasAnyRestorableData = true

        let localDate = CloudAccountDataDateCodec.localDateString(
            from: referenceDate,
            calendar: Calendar(identifier: .gregorian)
        )
        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: currentUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: currentUID
        )
        try await remoteStore.saveFoodEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
                userId: currentUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: currentUID
        )

        initialRestore.remoteStore = remoteStore
        initialRestore.profileStore = profileStore
        initialRestore.store = store
        initialRestore.profileService = profileService
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
            caloriesConsumed: 400,
            proteinConsumed: 20,
            carbsConsumed: 30,
            fatConsumed: 12,
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

    func foodCount() throws -> Int {
        try store.fetch(FetchDescriptor<FoodEntryEntity>()).count
    }
}

private enum RestoreCoordinatorFeatureGate {
    static var isRestoreEnabled = false
}

private final class CurrentUIDBox {
    var uid: String

    init(uid: String) {
        self.uid = uid
    }
}

@MainActor
private final class RecordingInitialRestoreService: AccountInitialRestoring {

    var blockingCallCount = 0
    var backgroundCallCount = 0
    var blockingDelayNanoseconds: UInt64 = 0
    var blockingUIDProvider: (() -> String)?
    var currentUIDProvider: (() -> String?)?
    var remoteStore: InMemoryAccountDataRemoteStore?
    var profileStore: RestoreCoordinatorProfileStore?
    var store: SwiftDataStore?
    var profileService: UserProfileService?

    private let referenceDate: Date
    private lazy var fallbackService: AccountInitialRestoreService? = {
        guard let store, let profileService, let remoteStore, let profileStore else { return nil }
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let puller = AccountSyncPuller(remoteStore: remoteStore, store: store)
        let localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: outbox
        )
        let remoteInspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: remoteStore
        )
        return AccountInitialRestoreService(
            profileBootstrapService: ProfileBootstrapService(
                userProfileService: profileService,
                cloudStore: profileStore
            ),
            puller: puller,
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            stateStore: AccountRestoreStateStore(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!
            ),
            dailyLogService: DailyLogService(
                store: store,
                userProfileService: profileService
            ),
            currentUIDProvider: { [weak self] in self?.currentUIDProvider?() }
        )
    }()

    init(referenceDate: Date) {
        self.referenceDate = referenceDate
    }

    func runBlockingInitialRestore(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        blockingCallCount += 1
        _ = blockingUIDProvider?()
        if blockingDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: blockingDelayNanoseconds)
        }
        if let fallbackService {
            return await fallbackService.runBlockingInitialRestore(uid: uid, reason: reason)
        }
        return AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .blockingInitial,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
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

    func runBackgroundBackfill(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        backgroundCallCount += 1
        return runBlockingInitialRestore(uid: uid, reason: reason)
    }
}

@MainActor
private final class RecordingSyncCoordinator: AccountSyncCoordinating {
    var uploadCallCount = 0

    func syncNow(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        AccountSyncRunSummary(
            uid: uid,
            reason: reason,
            startedAt: Date(),
            endedAt: Date(),
            uploadSummary: nil,
            pullSummary: nil,
            didSkip: true,
            skipReason: nil
        )
    }

    func uploadPendingOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        uploadCallCount += 1
        return AccountSyncRunSummary(
            uid: uid,
            reason: reason,
            startedAt: Date(),
            endedAt: Date(),
            uploadSummary: nil,
            pullSummary: nil,
            didSkip: false,
            skipReason: nil
        )
    }

    func pullRecentOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        AccountSyncRunSummary(
            uid: uid,
            reason: reason,
            startedAt: Date(),
            endedAt: Date(),
            uploadSummary: nil,
            pullSummary: nil,
            didSkip: true,
            skipReason: nil
        )
    }

    func cancelPendingWork() {}
}

private struct StubRemoteInspector: AccountRemoteDataInspecting {
    var hasCloudProfile = false
    var hasAnyRestorableData = false
    var failure: AccountRemoteDataInspectionFailure?

    func inspectRemoteData(for uid: String, today: Date) async -> AccountRemoteDataStatus {
        AccountRemoteDataStatus(
            uid: uid,
            hasCloudProfile: hasCloudProfile,
            hasRecentDailyLogs: hasAnyRestorableData,
            hasRecentFoodEntries: hasAnyRestorableData,
            hasRecentWaterEntries: false,
            hasWeightHistory: false,
            hasDailyReviews: false,
            hasAnyRestorableData: hasAnyRestorableData,
            newestRemoteUpdatedAt: nil,
            failure: failure
        )
    }
}

private struct RestoreCoordinatorProfileStore: CloudUserProfileStoring, @unchecked Sendable {
    var document: CloudUserProfileDocument?

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        _ = uid
        return document
    }

    func save(profile: UserProfile, uid: String) async throws {
        _ = profile
        _ = uid
    }
}
