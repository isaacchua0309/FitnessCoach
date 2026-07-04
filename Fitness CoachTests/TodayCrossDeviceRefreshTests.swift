//
//  TodayCrossDeviceRefreshTests.swift
//  Fitness CoachTests
//
//  Forma — Today Phase 5 cross-device refresh tests.
//

import Combine
import XCTest
@testable import Fitness_Coach

final class TodayCrossDeviceRefreshPolicyTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileTestFixtures.referenceDate

    func testShouldReloadForTodayRelevantDomains() {
        for domain in TodayCrossDeviceRefreshPolicy.relevantDomains {
            let event = AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [domain],
                reason: .realtimeSnapshot,
                createdAt: referenceDate
            )
            XCTAssertTrue(TodayCrossDeviceRefreshPolicy.shouldReload(for: event))
        }
    }

    func testShouldIgnoreCoachOnlyDomain() {
        let event = AccountDataRefreshEvent(
            uid: ownerUID,
            domains: [.coachContext],
            reason: .realtimeSnapshot,
            createdAt: referenceDate
        )
        XCTAssertFalse(TodayCrossDeviceRefreshPolicy.shouldReload(for: event))
    }

    func testMatchesCurrentUIDRejectsOtherAccounts() {
        let event = AccountDataRefreshEvent(
            uid: "other-user",
            domains: [.today],
            reason: .appForeground,
            createdAt: referenceDate
        )
        XCTAssertFalse(
            TodayCrossDeviceRefreshPolicy.matchesCurrentUID(
                event: event,
                ownerUIDProvider: { self.ownerUID }
            )
        )
    }
}

@MainActor
final class TodayCrossDeviceRefreshModelTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var crossDeviceCoordinator: TrackingTodayCrossDeviceSyncCoordinator!
    private var sessionUID: String!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        refreshEventBus = AccountDataRefreshEventBus()
        crossDeviceCoordinator = TrackingTodayCrossDeviceSyncCoordinator()
        sessionUID = "test-user-1"
        _ = try harness.seedProfile(ownerUID: sessionUID)
    }

    override func tearDown() {
        harness = nil
        refreshEventBus = nil
        crossDeviceCoordinator = nil
        sessionUID = nil
        super.tearDown()
    }

    func testModelIgnoresRefreshEventsForOtherUID() async throws {
        let model = try makeModel()
        await model.loadToday()

        refreshEventBus.publish(
            AccountDataRefreshEvent(
                uid: "other-user",
                domains: [.food],
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
        refreshEventBus.flushImmediately()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(crossDeviceCoordinator.manualRefreshCallCount, 0)
    }

    func testModelReloadsAfterRelevantCrossDeviceEvent() async throws {
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

        refreshEventBus.publish(
            AccountDataRefreshEvent(
                uid: sessionUID,
                domains: [.food],
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
        refreshEventBus.flushImmediately()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(state.meals.entryCount, 1)
    }

    func testManualCrossDeviceRefreshDoesNotClearLoadedState() async throws {
        let model = try makeModel()
        await model.loadToday()
        crossDeviceCoordinator.manualRefreshDelayNanoseconds = 100_000_000

        async let refreshTask = model.performManualCrossDeviceRefresh()
        try await Task.sleep(nanoseconds: 20_000_000)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded state during cross-device refresh")
        }
        await refreshTask

        XCTAssertEqual(crossDeviceCoordinator.manualRefreshCallCount, 1)
        XCTAssertFalse(model.isCrossDeviceRefreshing)
    }

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
}

@MainActor
private final class TrackingTodayCrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

    var manualRefreshCallCount = 0
    var manualRefreshDelayNanoseconds: UInt64 = 0

    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        emptySummary(uid: uid, mode: mode, reason: reason)
    }

    func foregroundRefreshIfNeeded(uid: String) async -> CrossDeviceSyncSummary? { nil }

    func manualRefresh(uid: String) async -> CrossDeviceSyncSummary {
        manualRefreshCallCount += 1
        if manualRefreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: manualRefreshDelayNanoseconds)
        }
        return emptySummary(uid: uid, mode: .manualRefresh, reason: .manualPullToRefresh)
    }

    func handleRealtimeHint(uid: String) async -> CrossDeviceSyncSummary? { nil }

    private func emptySummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .completed,
            startedAt: Date(),
            endedAt: Date(),
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )
    }
}
