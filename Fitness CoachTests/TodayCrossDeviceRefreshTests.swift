//
//  TodayCrossDeviceRefreshTests.swift
//  Fitness CoachTests
//
//  Forma — Today Phase 5 cross-device refresh tests.
//

import Combine
import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayCrossDeviceRefreshTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var crossDeviceCoordinator: FeatureCrossDeviceSyncCoordinator!
    private var sessionUID: String!
    private let otherUID = "other-user"

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        refreshEventBus = AccountDataRefreshEventBus()
        crossDeviceCoordinator = FeatureCrossDeviceSyncCoordinator()
        sessionUID = harness.cloudUID
        _ = try harness.seedProfile(ownerUID: sessionUID)
    }

    override func tearDown() {
        harness = nil
        refreshEventBus = nil
        crossDeviceCoordinator = nil
        sessionUID = nil
        super.tearDown()
    }

    func testTodayReloadsAfterRemoteFoodChange() async throws {
        let model = try makeModel()
        await model.loadToday()

        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(
                name: "Oats",
                calories: 300,
                protein: 12,
                carbs: 40,
                fat: 8
            ),
            date: harness.today
        )

        try await publishRefresh(domains: [.food])

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(state.meals.entryCount, 1)
        XCTAssertEqual(state.meals.entries.first?.name, "Oats")
    }

    func testTodayReloadsAfterRemoteWaterChange() async throws {
        let model = try makeModel()
        await model.loadToday()

        _ = try harness.actionCenter.logWater(amountMl: 450, date: harness.today)

        try await publishRefresh(domains: [.water])

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(state.macroHydration.waterSummary.consumedMl, 450)
    }

    func testTodayReloadsAfterRemoteWeightChange() async throws {
        let model = try makeModel()
        await model.loadToday()

        _ = try harness.actionCenter.logWeight(82.5, date: harness.today)

        try await publishRefresh(domains: [.weight])

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(state.mission.weightSummary.weightKg ?? 0, 82.5, accuracy: 0.01)
    }

    func testTodayUpdatesTargetsAfterRemotePlanChange() async throws {
        let model = try makeModel()
        await model.loadToday()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(initial.mission.calorieSummary.target, 1_800)

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: ProfileTestFixtures.sampleTargets.withCalories(2_100))
        )

        try await publishRefresh(domains: [.plan])

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Today state after plan refresh")
        }
        XCTAssertEqual(updated.mission.calorieSummary.target, 2_100)
    }

    func testTodayIgnoresRefreshEventForOtherUID() async throws {
        let model = try makeModel()
        await model.loadToday()

        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Snack", calories: 200),
            date: harness.today
        )

        try await publishRefresh(domains: [.food], uid: otherUID)

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(state.meals.entryCount, 0)
        XCTAssertTrue(state.meals.isEmpty)
    }

    func testTodayManualRefreshCallsCoordinator() async throws {
        let model = try makeModel()
        await model.loadToday()

        await model.performManualCrossDeviceRefresh()

        XCTAssertEqual(crossDeviceCoordinator.manualRefreshCallCount, 1)
        XCTAssertFalse(model.isCrossDeviceRefreshing)
    }

    func testTodayKeepsLocalPendingEditVisible() async throws {
        let model = try makeModel()
        await model.loadToday()

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Local Draft", calories: 420),
            date: harness.today
        )
        try markFoodPendingUpload(entryID: entry.id, name: "Local Draft")

        try await publishRefresh(domains: [.food])

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(state.meals.entryCount, 1)
        XCTAssertEqual(state.meals.entries.first?.name, "Local Draft")
    }

    // MARK: - Helpers

    private func makeModel() throws -> TodayModel {
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: sessionUID),
            profile: try harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )
        let reviewService = ReviewService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.base.foodLogService,
            waterLogService: harness.base.waterLogService,
            weightLogService: harness.weightLogService,
            healthActivityQuery: harness.healthActivityQuery,
            userProfileService: harness.profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )
        return TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: reviewService,
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: self.sessionUID) },
            ownerUIDProvider: { self.sessionUID },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceCoordinator
        )
    }

    private func publishRefresh(
        domains: Set<AccountDataRefreshDomain>,
        uid: String? = nil
    ) async throws {
        try await CrossDeviceRefreshTestSupport.publishAndWait(
            bus: refreshEventBus,
            event: AccountDataRefreshEvent(
                uid: uid ?? sessionUID,
                domains: domains,
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
    }

    private func markFoodPendingUpload(entryID: UUID, name: String) throws {
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == entryID })
        descriptor.fetchLimit = 1
        let entity = try XCTUnwrap(try harness.store.fetchOne(descriptor))
        entity.name = name
        entity.syncStatus = .pendingUpload
        entity.localUpdatedAt = harness.today
        try harness.store.save()
    }
}
