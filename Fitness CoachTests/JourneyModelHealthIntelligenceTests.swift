//
//  JourneyModelHealthIntelligenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class JourneyModelHealthIntelligenceTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: MockJourneyHealthIntelligenceSnapshotService!
    private var healthRepository: MockJourneyHealthDataRepository!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = MockJourneyHealthIntelligenceSnapshotService()
        healthRepository = MockJourneyHealthDataRepository()
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        healthRepository = nil
        super.tearDown()
    }

    func testHealthIntelligenceDisabledLeavesSectionStateNil() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = makeModel(loadEnabled: false, uiEnabled: false, trainingConnected: true)

        await model.refresh()

        XCTAssertNil(model.journeyHealthIntelligenceSectionState)
        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testUIEnabledLoadsAndMapsHealthIntelligenceSection() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)
        let model = makeModel(loadEnabled: true, uiEnabled: true, trainingConnected: true)

        await model.refresh()

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState)
        XCTAssertEqual(
            model.journeyHealthIntelligenceSectionState?.recoveryTimeline.phase,
            .loaded
        )
        XCTAssertNil(model.journeyHealthIntelligenceSectionState?.connectHealthCTA)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testDebugFetchWithoutUIAvoidsPublishedSectionWhenUIEnabledFalse() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)
        let model = makeModel(loadEnabled: true, uiEnabled: false, trainingConnected: true)

        await model.refresh()

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNil(model.journeyHealthIntelligenceSectionState)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testSnapshotUnavailableUsesConnectHealthFallbackWhenUIEnabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = nil
        let model = makeModel(loadEnabled: true, uiEnabled: true, trainingConnected: false)

        await model.refresh()

        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState)
        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState?.connectHealthCTA)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testHealthIntelligenceFailureDoesNotFailJourneyRefresh() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = nil
        let model = makeModel(loadEnabled: true, uiEnabled: true, trainingConnected: true)

        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard despite Health Intelligence fallback")
        }
        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState)
    }

    func testAppleHealthDeniedShowsConnectHealthCTA() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        healthRepository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: 0
        )
        snapshotProvider.snapshot = nil
        let model = makeModel(loadEnabled: true, uiEnabled: true, trainingConnected: false)

        await model.refresh()

        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState?.connectHealthCTA)
        XCTAssertEqual(
            model.journeyHealthIntelligenceSectionState?.workoutHistory.emptyKind,
            .noHealthData
        )
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testConnectedNoWorkoutsShowsSupportiveWorkoutEmptyState() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)
        healthRepository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 3
        )
        let model = makeModel(loadEnabled: true, uiEnabled: true, trainingConnected: true)

        await model.refresh()

        XCTAssertNil(model.journeyHealthIntelligenceSectionState?.connectHealthCTA)
        XCTAssertEqual(
            model.journeyHealthIntelligenceSectionState?.workoutHistory.emptyKind,
            .connectedNoWorkouts
        )
    }

    // MARK: - Helpers

    private func makeModel(
        loadEnabled: Bool,
        uiEnabled: Bool,
        trainingConnected: Bool
    ) -> JourneyModel {
        let integration = StubTrainingIntegrationProvider(
            refreshResult: trainingConnected ? .connected : .notConnected
        )
        let trainingStore = TrainingInsightsStore(integration: integration)

        return JourneyModel(
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: trainingStore,
            workoutReader: MockHealthKitWorkoutReader(workouts: []),
            healthIntelligenceSnapshotProvider: snapshotProvider,
            healthIntelligenceEngine: NoOpHealthIntelligenceEngine(),
            healthCacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: harness.healthActivityQuery,
            healthDataRepository: healthRepository,
            healthIntelligenceLoadEnabled: { loadEnabled },
            healthIntelligenceUIEnabled: { uiEnabled }
        )
    }

    private func makeReadySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "Train based on how you feel.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: .none
        )
    }
}

// MARK: - Mocks

private final class MockJourneyHealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?
    private(set) var loadCallCount = 0

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        loadCallCount += 1
        return snapshot
    }
}

private final class MockJourneyHealthDataRepository: HealthDataRepositorying, @unchecked Sendable {
    var availability = HealthDataAvailability(
        isHealthDataAvailable: true,
        permissionStatus: .uniform(.available, isHealthDataAvailable: true),
        cachedDayCount: 0
    )

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] {
        []
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        availability
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}
