//
//  JourneyCrossDeviceRefreshTests.swift
//  Fitness CoachTests
//
//  Forma — Journey Phase 5 cross-device refresh tests.
//

import Combine
import XCTest
@testable import Fitness_Coach

final class JourneyCrossDeviceRefreshPolicyTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileTestFixtures.referenceDate

    func testShouldReloadForJourneyRelevantDomains() {
        for domain in JourneyCrossDeviceRefreshPolicy.relevantDomains {
            let event = AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [domain],
                reason: .realtimeSnapshot,
                createdAt: referenceDate
            )
            XCTAssertTrue(JourneyCrossDeviceRefreshPolicy.shouldReload(for: event))
        }
    }

    func testShouldIgnoreCoachOnlyDomain() {
        let event = AccountDataRefreshEvent(
            uid: ownerUID,
            domains: [.coachContext],
            reason: .realtimeSnapshot,
            createdAt: referenceDate
        )
        XCTAssertFalse(JourneyCrossDeviceRefreshPolicy.shouldReload(for: event))
    }

    func testMatchesCurrentUIDRejectsOtherAccounts() {
        let event = AccountDataRefreshEvent(
            uid: "other-user",
            domains: [.journey],
            reason: .appForeground,
            createdAt: referenceDate
        )
        XCTAssertFalse(
            JourneyCrossDeviceRefreshPolicy.matchesCurrentUID(
                event: event,
                ownerUIDProvider: { self.ownerUID }
            )
        )
    }
}

@MainActor
final class JourneyCrossDeviceRefreshModelTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var crossDeviceCoordinator: TrackingJourneyCrossDeviceSyncCoordinator!
    private var sessionUID: String!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        refreshEventBus = AccountDataRefreshEventBus()
        crossDeviceCoordinator = TrackingJourneyCrossDeviceSyncCoordinator()
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
        let model = makeModel()
        await model.loadProgress()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded journey state")
        }

        _ = try harness.actionCenter.logWeight(82.5, date: harness.today)
        refreshEventBus.publish(
            AccountDataRefreshEvent(
                uid: "other-user",
                domains: [.weight],
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
        refreshEventBus.flushImmediately()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let unchanged) = model.viewState else {
            return XCTFail("Expected loaded journey state after ignored event")
        }
        XCTAssertEqual(initial.baseline.currentWeightKg, unchanged.baseline.currentWeightKg)
    }

    func testModelReloadsAfterRelevantCrossDeviceEvent() async throws {
        let model = makeModel()
        await model.loadProgress()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded journey state")
        }
        XCTAssertNotEqual(initial.baseline.currentWeightKg, 82.5)

        _ = try harness.actionCenter.logWeight(82.5, date: harness.today)
        refreshEventBus.publish(
            AccountDataRefreshEvent(
                uid: sessionUID,
                domains: [.weight],
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
        refreshEventBus.flushImmediately()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded journey state after refresh")
        }
        XCTAssertEqual(updated.baseline.currentWeightKg ?? 0, 82.5, accuracy: 0.01)
    }

    func testManualCrossDeviceRefreshKeepsLoadedStateVisible() async throws {
        let model = makeModel()
        await model.loadProgress()
        crossDeviceCoordinator.manualRefreshDelayNanoseconds = 100_000_000

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded journey state")
        }

        async let refreshTask = model.performManualCrossDeviceRefresh()
        try await Task.sleep(nanoseconds: 20_000_000)

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded state during cross-device refresh")
        }

        await refreshTask
        XCTAssertEqual(crossDeviceCoordinator.manualRefreshCallCount, 1)
        XCTAssertFalse(model.isCrossDeviceRefreshing)
    }

    func testRefreshFailurePreservesLoadedDashboard() async throws {
        let failingReader = FailableDailyLogReader(underlying: harness.dailyLogService)
        let model = makeModel(dailyLogReader: failingReader)
        await model.loadProgress()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded journey state")
        }

        failingReader.failOnNextRead()
        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded state to be preserved after refresh failure")
        }
    }

    private func makeModel(
        dailyLogReader: (any DailyLogReading)? = nil,
        weightLogReader: (any WeightLogReading)? = nil
    ) -> JourneyModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return JourneyModel(
            dailyLogReader: dailyLogReader ?? harness.dailyLogService,
            weightLogReader: weightLogReader ?? harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: trainingStore,
            ownerUIDProvider: { self.sessionUID },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceCoordinator
        )
    }
}

@MainActor
private final class TrackingJourneyCrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

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

@MainActor
private final class FailableDailyLogReader: DailyLogReading {
    private let underlying: any DailyLogReading
    private var shouldFail = false

    init(underlying: any DailyLogReading) {
        self.underlying = underlying
    }

    func failOnNextRead() {
        shouldFail = true
    }

    func getTodayLog() throws -> DailyLog {
        if shouldFail { throw ServiceError.persistenceFailed("simulated failure") }
        return try underlying.getTodayLog()
    }

    func getLogs(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
        if shouldFail { throw ServiceError.persistenceFailed("simulated failure") }
        return try underlying.getLogs(from: startDate, to: endDate)
    }

    func getLog(for date: Date) throws -> DailyLog? {
        if shouldFail { throw ServiceError.persistenceFailed("simulated failure") }
        return try underlying.getLog(for: date)
    }
}
