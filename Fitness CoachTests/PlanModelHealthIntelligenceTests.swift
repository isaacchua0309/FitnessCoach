//
//  PlanModelHealthIntelligenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanModelHealthIntelligenceTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: PlanMockSnapshotService!
    private var baselineProvider: PlanMockBaselineProvider!
    private var healthRepository: PlanMockHealthDataRepository!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = PlanMockSnapshotService()
        baselineProvider = PlanMockBaselineProvider()
        healthRepository = PlanMockHealthDataRepository(connected: true)
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        baselineProvider = nil
        healthRepository = nil
        super.tearDown()
    }

    func testHealthIntelligenceDisabledLeavesSectionStateNil() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = makeModel(loadEnabled: false, uiEnabled: false)

        await model.loadProfile()

        XCTAssertNil(model.planHealthIntelligenceSectionState)
        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testUIEnabledLoadsAndMapsPlanHealthIntelligenceSection() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeSnapshot(on: Date())
        baselineProvider.context = makeBaseline(on: Date())
        let model = makeModel(loadEnabled: true, uiEnabled: true)

        await model.loadProfile()

        XCTAssertEqual(snapshotProvider.loadCallCount, 1, "Plan should compose snapshot once per refresh")
        XCTAssertNotNil(model.planHealthIntelligenceSectionState)
        XCTAssertEqual(
            model.planHealthIntelligenceSectionState?.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate
        )
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testDebugFetchWithoutUIStillAvoidsPublishedSectionWhenUIEnabledFalse() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeSnapshot(on: Date())
        let model = makeModel(loadEnabled: true, uiEnabled: false)

        await model.loadProfile()

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNil(model.planHealthIntelligenceSectionState)
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testSnapshotUnavailableUsesFallbackWhenUIEnabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = nil
        baselineProvider.context = makeBaseline(on: Date())
        let model = makeModel(loadEnabled: true, uiEnabled: true)

        await model.loadProfile()

        XCTAssertNotNil(model.planHealthIntelligenceSectionState)
        XCTAssertEqual(
            model.planHealthIntelligenceSectionState?.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceUnknown
        )
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testHealthIntelligenceFailureDoesNotFailPlanRefresh() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.shouldFailLoad = true
        let model = makeModel(loadEnabled: true, uiEnabled: true)

        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Plan dashboard despite Health Intelligence fallback")
        }
        XCTAssertNotNil(model.planHealthIntelligenceSectionState)
    }

    // MARK: - Helpers

    private func makeModel(
        loadEnabled: Bool,
        uiEnabled: Bool,
        trainingConnected: Bool = true
    ) -> PlanModel {
        let integration = StubTrainingIntegrationProvider(
            refreshResult: trainingConnected ? .connected : .notConnected
        )
        let trainingStore = TrainingInsightsStore(integration: integration)

        return PlanModel(
            actionCenter: harness.actionCenter,
            userProfileReader: harness.profileService,
            planTargetCalculator: harness.targetService,
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            trainingInsightsStore: trainingStore,
            healthBaselineService: baselineProvider,
            healthIntelligenceSnapshotProvider: snapshotProvider,
            healthDataRepository: healthRepository,
            healthIntelligenceLoadEnabled: { loadEnabled },
            healthIntelligenceUIEnabled: { uiEnabled }
        )
    }

    private func makeSnapshot(on day: Date) -> HealthIntelligenceSnapshot {
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

    private func makeBaseline(on day: Date) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: day,
            averageSteps7d: 8_450,
            averageSteps28d: 7_900,
            averageActiveEnergy7d: 420,
            averageActiveEnergy28d: 390,
            averageSleepDuration7d: 426,
            averageSleepDuration28d: 408,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 52,
            averageWorkoutLoad28d: 180,
            workoutDays7d: 4,
            workoutDays28d: 12,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: []
        )
    }
}

// MARK: - Mocks

private final class PlanMockSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?
    var shouldFailLoad = false
    private(set) var loadCallCount = 0

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        loadCallCount += 1
        if shouldFailLoad {
            return nil
        }
        return snapshot
    }
}

private struct PlanMockBaselineProvider: HealthBaselineProviding {
    var context: HealthBaselineContext = .empty(for: Date())

    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthBaselineContext {
        context
    }
}

private final class PlanMockHealthDataRepository: HealthDataRepositorying, @unchecked Sendable {
    let connected: Bool

    init(connected: Bool) {
        self.connected = connected
    }

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
        HealthDataAvailability(
            isHealthDataAvailable: connected,
            permissionStatus: connected
                ? .uniform(.available, isHealthDataAvailable: true)
                : .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: connected ? 1 : 0
        )
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}

private extension PlanViewState {
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}
