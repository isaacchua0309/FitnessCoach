//
//  AccountRestoreEndToEndTests.swift
//  Fitness CoachTests
//
//  Forma — End-to-end reinstall / new-device account restore simulations (Phase 4).
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountRestoreEndToEndTests: XCTestCase {

    private let userA = "userA"
    private let userB = "userB"
    private let referenceDate = ProfileFixtures.referenceDate
    private var calendar: Calendar!
    private var localDate: String!

    override func setUp() async throws {
        try await super.setUp()
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = gregorian
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        EndToEndRestoreFeatureGate.isRestoreEnabled = true
    }

    override func tearDown() async throws {
        EndToEndRestoreFeatureGate.isRestoreEnabled = false
        try await super.tearDown()
    }

    func testReinstallSameAccountRestoresNutritionHistory() async throws {
        let harness = try AccountRestoreEndToEndHarness.make(
            signedInUID: userA,
            referenceDate: referenceDate,
            calendar: calendar
        )
        try await harness.seedFullCloudNutritionData(for: userA)

        XCTAssertNil(try harness.profileService.getCurrentProfile())
        XCTAssertTrue(try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).isEmpty)

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userA,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .completed)
        XCTAssertNotNil(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(try harness.profileService.getCurrentProfile()?.ownerUID, userA)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).isEmpty)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<WaterEntryEntity>()).isEmpty)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<WeightEntryEntity>()).isEmpty)
        XCTAssertEqual(harness.stateStore.loadState(uid: userA).status, .completed)
    }

    func testReinstallSameAccountJourneyCanRebuild() async throws {
        let harness = try AccountRestoreEndToEndHarness.make(
            signedInUID: userA,
            referenceDate: referenceDate,
            calendar: calendar
        )
        try await harness.seedMultiDayCloudHistory(for: userA, dayCount: 14)

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userA,
            reason: .afterSignIn
        )
        XCTAssertEqual(summary.status, .completed)

        let journeyModel = harness.makeJourneyModel()
        await journeyModel.loadProgress()

        guard case .loaded(let state) = journeyModel.viewState else {
            return XCTFail("Expected loaded journey after restore, got \(journeyModel.viewState)")
        }
        XCTAssertTrue(state.hasProfile)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).isEmpty)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<WeightEntryEntity>()).isEmpty)
    }

    func testNewDeviceLoginRestoresToday() async throws {
        let harness = try AccountRestoreEndToEndHarness.make(
            signedInUID: userB,
            referenceDate: referenceDate,
            calendar: calendar
        )
        try await harness.seedTodayCloudNutritionData(for: userB)

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userB,
            reason: .newDevice
        )
        XCTAssertEqual(summary.status, .completed)

        let todayModel = try harness.makeTodayModel(ownerUID: userB)
        await todayModel.loadToday()

        guard case .loaded(let dashboard) = todayModel.viewState else {
            return XCTFail("Expected loaded Today after restore, got \(todayModel.viewState)")
        }
        XCTAssertEqual(dashboard.mission.calorieSummary.consumed, 520)
        XCTAssertFalse(try harness.foodLogService.getFoodEntries(for: referenceDate).isEmpty)
        XCTAssertFalse(try harness.waterLogService.getWaterEntries(for: referenceDate).isEmpty)
    }

    func testRestoreDoesNotPullOtherUserData() async throws {
        let harness = try AccountRestoreEndToEndHarness.make(
            signedInUID: userB,
            referenceDate: referenceDate,
            calendar: calendar
        )
        try await harness.seedFullCloudNutritionData(for: userA)
        try await harness.seedFullCloudNutritionData(for: userB, foodName: "User B Meal")

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userB,
            reason: .afterSignIn
        )
        XCTAssertEqual(summary.status, .completed)

        let dailyLogs = try harness.store.fetch(FetchDescriptor<DailyLogEntity>())
        let foods = try harness.store.fetch(FetchDescriptor<FoodEntryEntity>())
        XCTAssertFalse(dailyLogs.isEmpty)
        XCTAssertFalse(foods.isEmpty)
        XCTAssertTrue(dailyLogs.allSatisfy { $0.ownerUID == userB })
        XCTAssertTrue(foods.allSatisfy { $0.ownerUID == userB })
        XCTAssertEqual(foods.first?.name, "User B Meal")
        XCTAssertEqual(
            try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).filter { $0.ownerUID == userA }.count,
            0
        )
    }

    func testExistingLocalPendingEditNotOverwrittenByRemote() async throws {
        let harness = try AccountRestoreEndToEndHarness.make(
            signedInUID: userA,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let foodID = UUID()
        try await harness.seedFullCloudNutritionData(for: userA, foodID: foodID)

        let initialSummary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userA,
            reason: .afterSignIn
        )
        XCTAssertEqual(initialSummary.status, .completed)

        let food = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == foodID }
        )
        food.name = "Pending Local Edit"
        food.calories = 999
        food.syncStatus = .pendingUpload
        food.localUpdatedAt = referenceDate.addingTimeInterval(600)
        try harness.store.save()

        try await harness.seedFullCloudNutritionData(
            for: userA,
            foodID: foodID,
            foodName: "Stale Cloud Meal",
            calories: 100,
            updatedAt: referenceDate
        )

        let retrySummary = await harness.coordinator.retryRestore(uid: userA)

        XCTAssertTrue(retrySummary.skippedLocalNewer > 0 || retrySummary.status == .completed)
        let stored = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == foodID }
        )
        XCTAssertEqual(stored.name, "Pending Local Edit")
        XCTAssertEqual(stored.calories, 999)
        XCTAssertEqual(stored.syncStatus, .pendingUpload)
    }

    func testOfflineFreshInstallShowsOfflineRestoreState() async throws {
        let harness = try AccountRestoreEndToEndHarness.makeOffline(
            signedInUID: userB,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userB,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .offline)
        XCTAssertTrue(summary.allowsContinuedEntry)
        XCTAssertEqual(
            summary.userFacingMessage,
            AccountInitialRestoreServiceSupport.offlineRestoreMessage
        )
        XCTAssertFalse(summary.userFacingMessage?.contains("chicken") ?? true)
        XCTAssertEqual(harness.stateStore.loadState(uid: userB).status, .offline)
        XCTAssertTrue(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)
    }

    func testPartialRestoreStillAllowsMainApp() async throws {
        let harness = try await AccountRestoreEndToEndHarness.makeWithFailingRemote(
            signedInUID: userA,
            referenceDate: referenceDate,
            calendar: calendar,
            failingOperations: [.fetchWeightEntries]
        )
        try await harness.seedFullCloudNutritionData(for: userA)

        let summary = await harness.coordinator.prepareAccountAfterSignIn(
            uid: userA,
            reason: .afterSignIn
        )

        XCTAssertEqual(summary.status, .partial)
        XCTAssertTrue(summary.isPartial)
        XCTAssertTrue(summary.allowsContinuedEntry)
        XCTAssertNotNil(try harness.profileService.getCurrentProfile())
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).isEmpty)
        XCTAssertFalse(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)
        XCTAssertTrue(try harness.store.fetch(FetchDescriptor<WeightEntryEntity>()).isEmpty)

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: userA),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }
}

// MARK: - Feature gate

private enum EndToEndRestoreFeatureGate {
    static var isRestoreEnabled = false
}

// MARK: - Harness

@MainActor
private final class AccountRestoreEndToEndHarness {

    let store: SwiftDataStore
    let profileService: UserProfileService
    let dailyLogService: DailyLogService
    let foodLogService: FoodLogService
    let waterLogService: WaterLogService
    let weightLogService: WeightLogService
    let remoteStore: InMemoryAccountDataRemoteStore
    var profileStore: RestoreTestCloudProfileStore
    let networkChecker: RestoreTestNetworkChecker
    let stateStore: AccountRestoreStateStore
    let coordinator: AccountRestoreCoordinator
    let sessionState: AccountRestoreSessionState
    let signedInUID: String
    let referenceDate: Date
    let calendar: Calendar
    let localDate: String
    let healthActivityQuery: HealthActivityQueryService

    private let currentUIDBox: CurrentUIDBox

    init(
        store: SwiftDataStore,
        profileService: UserProfileService,
        dailyLogService: DailyLogService,
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        remoteStore: InMemoryAccountDataRemoteStore,
        profileStore: RestoreTestCloudProfileStore,
        networkChecker: RestoreTestNetworkChecker,
        stateStore: AccountRestoreStateStore,
        coordinator: AccountRestoreCoordinator,
        sessionState: AccountRestoreSessionState,
        signedInUID: String,
        referenceDate: Date,
        calendar: Calendar,
        localDate: String,
        healthActivityQuery: HealthActivityQueryService,
        currentUIDBox: CurrentUIDBox
    ) {
        self.store = store
        self.profileService = profileService
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.remoteStore = remoteStore
        self.profileStore = profileStore
        self.networkChecker = networkChecker
        self.stateStore = stateStore
        self.coordinator = coordinator
        self.sessionState = sessionState
        self.signedInUID = signedInUID
        self.referenceDate = referenceDate
        self.calendar = calendar
        self.localDate = localDate
        self.healthActivityQuery = healthActivityQuery
        self.currentUIDBox = currentUIDBox
    }

    static func make(
        signedInUID: String,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> AccountRestoreEndToEndHarness {
        try makeHarness(
            signedInUID: signedInUID,
            referenceDate: referenceDate,
            calendar: calendar,
            remoteStore: InMemoryAccountDataRemoteStore(),
            profileStore: RestoreTestCloudProfileStore(),
            networkChecker: RestoreTestNetworkChecker()
        )
    }

    static func makeOffline(
        signedInUID: String,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> AccountRestoreEndToEndHarness {
        var profileStore = RestoreTestCloudProfileStore()
        profileStore.fetchError = URLError(.notConnectedToInternet)
        return try makeHarness(
            signedInUID: signedInUID,
            referenceDate: referenceDate,
            calendar: calendar,
            remoteStore: InMemoryAccountDataRemoteStore(),
            remoteStoreInterface: EndToEndThrowingAccountDataRemoteStore(
                error: URLError(.notConnectedToInternet)
            ),
            profileStore: profileStore,
            networkChecker: RestoreTestNetworkChecker()
        )
    }

    static func makeWithFailingRemote(
        signedInUID: String,
        referenceDate: Date,
        calendar: Calendar,
        failingOperations: Set<SelectiveFailingAccountDataRemoteStore.FailingOperation>
    ) async throws -> AccountRestoreEndToEndHarness {
        let failingRemote = SelectiveFailingAccountDataRemoteStore(
            failingOperations: failingOperations
        )
        let backing = await failingRemote.backingStore()
        return try makeHarness(
            signedInUID: signedInUID,
            referenceDate: referenceDate,
            calendar: calendar,
            remoteStore: backing,
            remoteStoreInterface: failingRemote,
            profileStore: RestoreTestCloudProfileStore(),
            networkChecker: RestoreTestNetworkChecker()
        )
    }

    private static func makeHarness(
        signedInUID: String,
        referenceDate: Date,
        calendar: Calendar,
        remoteStore: InMemoryAccountDataRemoteStore,
        remoteStoreInterface: (any AccountDataRemoteStore)? = nil,
        profileStore: RestoreTestCloudProfileStore,
        networkChecker: RestoreTestNetworkChecker
    ) throws -> AccountRestoreEndToEndHarness {
        let defaults = UserDefaults(suiteName: "AccountRestoreEndToEndTests.\(UUID().uuidString)")!
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let currentUIDBox = CurrentUIDBox(uid: signedInUID)
        let mutationTracker = AccountLocalMutationTracker(
            outbox: outbox,
            ownerUIDProvider: { currentUIDBox.uid }
        )
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            mutationTracker: mutationTracker
        )
        let foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: mutationTracker
        )
        let waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: mutationTracker
        )
        let weightLogService = WeightLogService(
            store: store,
            dailyLogService: dailyLogService,
            dateProvider: dateProvider,
            mutationTracker: mutationTracker
        )
        let resolvedRemote = remoteStoreInterface ?? remoteStore
        let puller = AccountSyncPuller(
            remoteStore: resolvedRemote,
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
        let remoteInspector = AccountRemoteDataInspector(
            cloudProfileStore: profileStore,
            remoteStore: resolvedRemote,
            calendar: calendar
        )
        let stateStore = AccountRestoreStateStore(userDefaults: defaults)
        let profileBootstrap = ProfileBootstrapService(
            userProfileService: profileService,
            cloudStore: profileStore
        )
        let syncCoordinator = EndToEndRecordingSyncCoordinator()
        let healthCache = LocalHealthCacheStore()
        let namespaceService = AccountDataNamespaceService(
            store: store,
            healthCacheStore: healthCache,
            userDefaults: defaults,
            syncCoordinator: syncCoordinator
        )
        let migrationService = RecordingAccountMigrationService()
        let initialRestore = AccountInitialRestoreService(
            profileBootstrapService: profileBootstrap,
            puller: puller,
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            stateStore: stateStore,
            syncCoordinator: syncCoordinator,
            dailyLogService: dailyLogService,
            networkChecker: networkChecker,
            currentUIDProvider: { currentUIDBox.uid }
        )
        let coordinator = AccountRestoreCoordinator(
            namespaceService: namespaceService,
            migrationService: migrationService,
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            initialRestoreService: initialRestore,
            stateStore: stateStore,
            syncCoordinator: syncCoordinator,
            currentUIDProvider: { currentUIDBox.uid },
            restoreEnabledProvider: { EndToEndRestoreFeatureGate.isRestoreEnabled },
            dateProvider: dateProvider
        )
        let healthActivityQuery = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: []),
            stepReader: MockHealthKitStepReader(stepCount: 0)
        )

        return AccountRestoreEndToEndHarness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            remoteStore: remoteStore,
            profileStore: profileStore,
            networkChecker: networkChecker,
            stateStore: stateStore,
            coordinator: coordinator,
            sessionState: AccountRestoreSessionState(),
            signedInUID: signedInUID,
            referenceDate: referenceDate,
            calendar: calendar,
            localDate: CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar),
            healthActivityQuery: healthActivityQuery,
            currentUIDBox: currentUIDBox
        )
    }

    func seedFullCloudNutritionData(
        for uid: String,
        foodID: UUID = UUID(),
        foodName: String = "Cloud Oats",
        calories: Int = 420,
        updatedAt: Date? = nil
    ) async throws {
        let updated = updatedAt ?? referenceDate
        let profile = AccountRestoreTestSupport.makeProfile(ownerUID: uid, referenceDate: referenceDate)
        profileStore.document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: uid,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uid
        )

        var food = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: uid,
            localDate: localDate,
            referenceDate: updated,
            entryId: foodID.uuidString
        )
        food.name = foodName
        food.calories = calories
        food.updatedAt = updated
        try await remoteStore.saveFoodEntry(food, uid: uid)

        try await remoteStore.saveWaterEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
                userId: uid,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: uid
        )
        try await remoteStore.saveWeightEntry(
            FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
                userId: uid,
                localDate: localDate,
                referenceDate: referenceDate,
                entryId: "weight-\(uid)"
            ),
            uid: uid
        )
    }

    func seedTodayCloudNutritionData(for uid: String) async throws {
        try await seedFullCloudNutritionData(for: uid)
    }

    func seedMultiDayCloudHistory(for uid: String, dayCount: Int) async throws {
        let profile = AccountRestoreTestSupport.makeProfile(ownerUID: uid, referenceDate: referenceDate)
        profileStore.document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )

        for offset in 0..<dayCount {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: referenceDate))
            let dayLocalDate = CloudAccountDataDateCodec.localDateString(from: day, calendar: calendar)
            try await remoteStore.saveDailyLog(
                FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                    userId: uid,
                    localDate: dayLocalDate,
                    referenceDate: day
                ),
                uid: uid
            )
            try await remoteStore.saveWeightEntry(
                FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
                    userId: uid,
                    localDate: dayLocalDate,
                    referenceDate: day,
                    entryId: "weight-\(uid)-\(offset)"
                ),
                uid: uid
            )
        }
    }

    func makeTodayModel(ownerUID: String) throws -> TodayModel {
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: ownerUID),
            profile: try profileService.getCurrentProfile(),
            calendar: calendar,
            now: referenceDate
        )
        let reviewService = ReviewService(
            store: store,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthActivityQuery,
            userProfileService: profileService,
            aiService: AIService(llmClient: MockLLMClient()),
            mutationTracker: AccountLocalMutationTracker(
                outbox: SwiftDataAccountSyncOutboxStore(store: store),
                ownerUIDProvider: { ownerUID }
            )
        )
        return TodayModel(
            dailyLogReader: dailyLogService,
            foodLogReader: foodLogService,
            weightLogReader: weightLogService,
            dailyReviewReader: reviewService,
            userProfileReader: profileService,
            healthActivityQuery: healthActivityQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: ownerUID) },
            restoreSessionState: sessionState,
            localDataInspector: AccountLocalDataInspector(
                store: store,
                userProfileService: profileService,
                outboxStore: SwiftDataAccountSyncOutboxStore(store: store),
                dateProvider: FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar),
                calendar: calendar
            ),
            ownerUIDProvider: { ownerUID },
            healthIntelligenceLoadEnabled: { false }
        )
    }

    func makeJourneyModel() -> JourneyModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return JourneyModel(
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            userProfileReader: profileService,
            trainingInsightsStore: trainingStore,
            healthIntelligenceLoadEnabled: { false },
            restoreSessionState: sessionState,
            localDataInspector: AccountLocalDataInspector(
                store: store,
                userProfileService: profileService,
                outboxStore: SwiftDataAccountSyncOutboxStore(store: store),
                dateProvider: FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar),
                calendar: calendar
            ),
            ownerUIDProvider: { self.signedInUID }
        )
    }
}

private final class CurrentUIDBox {
    var uid: String
    init(uid: String) { self.uid = uid }
}

@MainActor
private final class EndToEndRecordingSyncCoordinator: AccountSyncCoordinating {
    func syncNow(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        skippedSummary(uid: uid, reason: reason)
    }

    func uploadPendingOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        skippedSummary(uid: uid, reason: reason)
    }

    func pullRecentOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        skippedSummary(uid: uid, reason: reason)
    }

    func cancelPendingWork() {}

    private func skippedSummary(uid: String, reason: AccountSyncReason) -> AccountSyncRunSummary {
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
}

private actor EndToEndThrowingAccountDataRemoteStore: AccountDataRemoteStore {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func fetchDailyLog(uid: String, localDate: String) async throws -> CloudDailyLogDocument? { throw error }
    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws { throw error }
    func fetchDailyLogs(uid: String, from startDate: String, to endDate: String) async throws -> [CloudDailyLogDocument] {
        throw error
    }
    func fetchFoodEntries(uid: String, localDate: String) async throws -> [CloudFoodEntryDocument] { throw error }
    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String) async throws { throw error }
    func deleteFoodEntry(uid: String, localDate: String, entryId: String) async throws { throw error }
    func fetchWaterEntries(uid: String, localDate: String) async throws -> [CloudWaterEntryDocument] { throw error }
    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String) async throws { throw error }
    func deleteWaterEntry(uid: String, localDate: String, entryId: String) async throws { throw error }
    func fetchWeightEntries(uid: String, from startDate: String?, to endDate: String?) async throws -> [CloudWeightEntryDocument] {
        throw error
    }
    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws { throw error }
    func deleteWeightEntry(uid: String, entryId: String) async throws { throw error }
    func fetchDailyReview(uid: String, localDate: String) async throws -> CloudDailyReviewDocument? { throw error }
    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String) async throws { throw error }
    func deleteDailyReview(uid: String, localDate: String) async throws { throw error }
    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? { throw error }
    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws { throw error }
    func fetchDailyLogsUpdatedSince(uid: String, since: Date?, limit: Int) async throws -> [CloudDailyLogDocument] {
        throw error
    }
    func fetchFoodEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudFoodEntryDocument] { throw error }
    func fetchWaterEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudWaterEntryDocument] { throw error }
    func fetchWeightEntriesUpdatedSince(uid: String, since: Date?, limit: Int) async throws -> [CloudWeightEntryDocument] {
        throw error
    }
    func fetchDailyReviewsUpdatedSince(uid: String, since: Date?, limit: Int) async throws -> [CloudDailyReviewDocument] {
        throw error
    }
    func fetchCloudProfileUpdatedSince(uid: String, since: Date?) async throws -> CloudUserProfileDocument? { throw error }
}
