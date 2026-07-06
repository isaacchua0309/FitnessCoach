//
//  CrossDeviceEndToEndSyncTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Two-device Phase 5 cross-device sync simulation harness.
//

import SwiftData
import XCTest
@testable import Fitness_Coach

final class FakeTestClock {
    var now: Date
    let calendar: Calendar

    init(referenceDate: Date, calendar: Calendar) {
        self.calendar = calendar
        self.now = calendar.startOfDay(for: referenceDate)
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

@MainActor
final class CrossDeviceEndToEndSimulation {

    let uid: String
    let otherUID: String
    let remoteStore: InMemoryAccountDataRemoteStore
    let deviceA: SimulatedCrossDevice
    let deviceB: SimulatedCrossDevice
    let calendar: Calendar
    let referenceDate: Date
    let localDate: String

    init(
        uid: String,
        otherUID: String,
        remoteStore: InMemoryAccountDataRemoteStore,
        deviceA: SimulatedCrossDevice,
        deviceB: SimulatedCrossDevice,
        calendar: Calendar,
        referenceDate: Date,
        localDate: String
    ) {
        self.uid = uid
        self.otherUID = otherUID
        self.remoteStore = remoteStore
        self.deviceA = deviceA
        self.deviceB = deviceB
        self.calendar = calendar
        self.referenceDate = referenceDate
        self.localDate = localDate
    }

    static func make(
        uid: String = "shared-user",
        otherUID: String = "other-user",
        referenceDate: Date = ProfileFixtures.referenceDate
    ) throws -> CrossDeviceEndToEndSimulation {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        let remoteStore = InMemoryAccountDataRemoteStore()
        let deviceA = try SimulatedCrossDevice.make(
            name: "A",
            uid: uid,
            remoteStore: remoteStore,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let deviceB = try SimulatedCrossDevice.make(
            name: "B",
            uid: uid,
            remoteStore: remoteStore,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return CrossDeviceEndToEndSimulation(
            uid: uid,
            otherUID: otherUID,
            remoteStore: remoteStore,
            deviceA: deviceA,
            deviceB: deviceB,
            calendar: calendar,
            referenceDate: referenceDate,
            localDate: localDate
        )
    }

    func bootstrapProfiles() async throws {
        try deviceA.seedProfile()
        try deviceB.seedProfile()
        try await pushProfileToCloud(from: deviceA)
    }

    func pushProfileToCloud(from device: SimulatedCrossDevice) async throws {
        guard let profile = try device.profileService.getCurrentProfile() else {
            XCTFail("Expected profile on \(device.name)")
            return
        }
        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: device.clock.now,
            updatedAt: device.clock.now
        )
        try await remoteStore.seedCloudProfile(document, uid: device.uid)
        device.profileCloudSyncStore.markSynced(uid: device.uid, updatedAt: document.updatedAt)
    }

    func seedForeignAccountFood() async throws {
        try await remoteStore.saveDailyLog(
            FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
                userId: otherUID,
                localDate: localDate,
                referenceDate: referenceDate
            ),
            uid: otherUID
        )
        var food = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: otherUID,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: UUID().uuidString
        )
        food.name = "Foreign Meal"
        try await remoteStore.saveFoodEntry(food, uid: otherUID)
    }
}

@MainActor
final class SimulatedCrossDevice {

    let name: String
    let uid: String
    let clock: FakeTestClock
    let store: SwiftDataStore
    let profileService: UserProfileService
    let dailyLogService: DailyLogService
    let foodLogService: FoodLogService
    let waterLogService: WaterLogService
    let weightLogService: WeightLogService
    let actionCenter: FitnessActionCenter
    let accountSyncCoordinator: AccountSyncCoordinator
    let crossDeviceSyncCoordinator: CrossDeviceSyncCoordinator
    let refreshEventBus: AccountDataRefreshEventBus
    let refreshCenter: AppRefreshCenter
    let profileCloudSyncStore: ProfileCloudSyncStore
    let networkChecker: CrossDeviceSyncNetworkCheckerMock
    let healthActivityQuery: HealthActivityQueryService
    let calendar: Calendar
    let localDate: String

    private let profileBootstrapService: ProfileBootstrapService

    init(
        name: String,
        uid: String,
        clock: FakeTestClock,
        store: SwiftDataStore,
        profileService: UserProfileService,
        dailyLogService: DailyLogService,
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        actionCenter: FitnessActionCenter,
        accountSyncCoordinator: AccountSyncCoordinator,
        crossDeviceSyncCoordinator: CrossDeviceSyncCoordinator,
        refreshEventBus: AccountDataRefreshEventBus,
        refreshCenter: AppRefreshCenter,
        profileCloudSyncStore: ProfileCloudSyncStore,
        networkChecker: CrossDeviceSyncNetworkCheckerMock,
        healthActivityQuery: HealthActivityQueryService,
        calendar: Calendar,
        localDate: String,
        profileBootstrapService: ProfileBootstrapService
    ) {
        self.name = name
        self.uid = uid
        self.clock = clock
        self.store = store
        self.profileService = profileService
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.actionCenter = actionCenter
        self.accountSyncCoordinator = accountSyncCoordinator
        self.crossDeviceSyncCoordinator = crossDeviceSyncCoordinator
        self.refreshEventBus = refreshEventBus
        self.refreshCenter = refreshCenter
        self.profileCloudSyncStore = profileCloudSyncStore
        self.networkChecker = networkChecker
        self.healthActivityQuery = healthActivityQuery
        self.calendar = calendar
        self.localDate = localDate
        self.profileBootstrapService = profileBootstrapService
    }

    static func make(
        name: String,
        uid: String,
        remoteStore: InMemoryAccountDataRemoteStore,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> SimulatedCrossDevice {
        let clock = FakeTestClock(referenceDate: referenceDate, calendar: calendar)
        let localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        let defaults = UserDefaults(suiteName: "CrossDeviceE2E.\(name).\(UUID().uuidString)")!
        let dateProvider = FixedDailyLogTestDateProvider(now: clock.now, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let mutationTracker = AccountLocalMutationTracker(
            outbox: outbox,
            ownerUIDProvider: { uid },
            calendar: calendar
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
        let payloadBuilder = SwiftDataAccountSyncPayloadBuilder(store: store, calendar: calendar)
        let uploader = AccountSyncUploader(
            outbox: outbox,
            payloadBuilder: payloadBuilder,
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { clock.now }
        )
        let puller = AccountSyncPuller(
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { clock.now }
        )
        let networkChecker = CrossDeviceSyncNetworkCheckerMock()
        let accountSyncCoordinator = AccountSyncCoordinator(
            uploader: uploader,
            puller: puller,
            networkChecker: networkChecker,
            currentUIDProvider: { uid },
            calendar: calendar,
            nowProvider: { clock.now },
            debounceInterval: .milliseconds(10)
        )
        let cursorStore = AccountSyncCursorStore(userDefaults: defaults)
        let profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: defaults)
        let profileBootstrapService = ProfileBootstrapService(
            userProfileService: profileService,
            cloudStore: RestoreTestCloudProfileStore(),
            cloudSyncStore: profileCloudSyncStore,
            dailyLogService: dailyLogService
        )
        let localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: outbox,
            dateProvider: dateProvider,
            calendar: calendar
        )
        let incrementalPuller = AccountIncrementalPuller(
            remoteStore: remoteStore,
            mergePuller: puller,
            cursorStore: cursorStore,
            profileBootstrapService: profileBootstrapService,
            userProfileService: profileService,
            profileCloudSyncStore: profileCloudSyncStore,
            localInspector: localInspector,
            currentUIDProvider: { uid },
            calendar: calendar,
            nowProvider: { clock.now }
        )
        let refreshCenter = AppRefreshCenter(now: clock.now)
        let refreshEventBus = AccountDataRefreshEventBus(nowProvider: { clock.now })
        let crossDeviceSyncCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: accountSyncCoordinator,
            incrementalPuller: incrementalPuller,
            cursorStore: cursorStore,
            networkChecker: networkChecker,
            currentUIDProvider: { uid },
            refreshCenter: refreshCenter,
            refreshEventBus: refreshEventBus,
            nowProvider: { clock.now }
        )
        let healthActivityQuery = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: []),
            stepReader: MockHealthKitStepReader(stepCount: 0)
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
            mutationTracker: mutationTracker
        )
        let targetService = TargetService(
            userProfileService: profileService,
            dailyLogService: dailyLogService
        )
        let actionCenter = FitnessActionCenter(
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            dailyLogService: dailyLogService,
            targetService: targetService,
            userProfileService: profileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            currentUIDProvider: { uid }
        )

        return SimulatedCrossDevice(
            name: name,
            uid: uid,
            clock: clock,
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            actionCenter: actionCenter,
            accountSyncCoordinator: accountSyncCoordinator,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator,
            refreshEventBus: refreshEventBus,
            refreshCenter: refreshCenter,
            profileCloudSyncStore: profileCloudSyncStore,
            networkChecker: networkChecker,
            healthActivityQuery: healthActivityQuery,
            calendar: calendar,
            localDate: localDate,
            profileBootstrapService: profileBootstrapService
        )
    }

    func seedProfile() throws {
        var draft = ProfileFixtures.sampleDraft
        draft.targets = ProfileFixtures.sampleTargets
        _ = try profileService.createProfile(draft)
        _ = try profileService.assignOwnerUID(uid)
        profileCloudSyncStore.markSynced(uid: uid, updatedAt: clock.now)
    }

    func uploadPending() async throws {
        let summary = await accountSyncCoordinator.uploadPendingOnly(
            for: uid,
            reason: .afterLocalMutation
        )
        let succeeded = summary.uploadSummary?.succeeded ?? 0
        XCTAssertGreaterThan(succeeded, 0, "Expected \(name) upload to succeed")
    }

    @discardableResult
    func pullFromCloud(
        mode: CrossDeviceSyncMode = .manualRefresh
    ) async throws -> CrossDeviceSyncSummary {
        let reason: CrossDeviceSyncReason = mode == .manualRefresh ? .manualPullToRefresh : .appForeground
        return await crossDeviceSyncCoordinator.refreshNow(
            uid: uid,
            mode: mode,
            reason: reason
        )
    }

    func makeTodayModel() throws -> TodayModel {
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: uid),
            profile: try profileService.getCurrentProfile(),
            calendar: calendar,
            now: clock.now
        )
        let reviewService = ReviewService(
            store: store,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthActivityQuery,
            userProfileService: profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )
        return TodayModel(
            dailyLogReader: dailyLogService,
            foodLogReader: foodLogService,
            weightLogReader: weightLogService,
            dailyReviewReader: reviewService,
            userProfileReader: profileService,
            healthActivityQuery: healthActivityQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: self.uid) },
            ownerUIDProvider: { self.uid },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
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
            ownerUIDProvider: { self.uid },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
        )
    }

    func makePlanModel() -> PlanModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        let targetService = TargetService(
            userProfileService: profileService,
            dailyLogService: dailyLogService
        )
        return PlanModel(
            actionCenter: actionCenter,
            userProfileReader: profileService,
            planTargetCalculator: targetService,
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            trainingInsightsStore: trainingStore,
            healthBaselineService: StubHealthBaselineProvider(),
            ownerUIDProvider: { self.uid },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
        )
    }

    func markFoodSynced(id: UUID) throws {
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let entity = try XCTUnwrap(try store.fetchOne(descriptor))
        entity.syncStatus = .synced
        entity.cloudId = id.uuidString
        entity.lastSyncedAt = clock.now
        try store.save()
    }
}
