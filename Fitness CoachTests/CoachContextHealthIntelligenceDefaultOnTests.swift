//
//  CoachContextHealthIntelligenceDefaultOnTests.swift
//  Fitness CoachTests
//
//  Verifies Coach Health Intelligence context is default-on with safe degradation.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachContextHealthIntelligenceDefaultOnTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var snapshotProvider: MockCoachHealthIntelligenceSnapshotProvider!
    private var trainingLoadEngine: StubCoachTrainingLoadEngine!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = harness.weightLogService
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        snapshotProvider = MockCoachHealthIntelligenceSnapshotProvider()
        trainingLoadEngine = StubCoachTrainingLoadEngine()
    }

    override func tearDown() {
        HealthIntelligenceFeatureFlags.testOverride = nil
        trainingLoadEngine = nil
        snapshotProvider = nil
        healthQuery = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    // MARK: - Default on

    func testProductionDefaultsEnableCoachHealthIntelligence() {
        let defaults = HealthIntelligenceFeatureFlags.snapshot()
        XCTAssertTrue(defaults.healthIntelligenceCoachContextEnabled)
        XCTAssertTrue(defaults.shouldCoachLoadHealthIntelligence)
    }

    func testDefaultOnIncludesHealthIntelligenceWhenSnapshotAvailable() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertEqual(packet.healthIntelligence?.recoveryStatus, RecoveryStatus.moderate.rawValue)
        XCTAssertEqual(packet.healthIntelligence?.recoveryScore, 72)
        XCTAssertEqual(packet.healthIntelligence?.recoveryConfidence, RecoveryConfidence.moderate.rawValue)
        XCTAssertEqual(
            packet.healthIntelligence?.adaptiveNutritionAdvice,
            "Keep calories steady and prioritize protein after training."
        )
        XCTAssertTrue(packet.sourceAttribution?.healthIntelligenceIncluded == true)
        XCTAssertEqual(packet.training?.trainingLoad, TrainingLoadStatus.unknown.rawValue)
    }

    func testOperationalOverrideDisablesHealthIntelligenceSection() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)

        let packet = await makeBuilder(loadHealthIntelligence: false).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertNil(packet.healthIntelligence)
        XCTAssertFalse(packet.sourceAttribution?.healthIntelligenceIncluded == true)
    }

    // MARK: - Safe degradation

    func testSnapshotUnavailableIncludesUnavailableHealthIntelligence() async {
        snapshotProvider.snapshot = nil

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertEqual(packet.healthIntelligence?.healthContextStatus, .unavailable)
        XCTAssertTrue(packet.missingData.healthKitUnavailable)
        XCTAssertEqual(packet.generationMode, .degraded)
    }

    func testTrainingLoadEngineFailureStillBuildsPacket() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)
        trainingLoadEngine.error = StubCoachTrainingLoadEngine.TestError.failed

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertEqual(packet.training?.trainingLoad, TrainingLoadStatus.unknown.rawValue)
        XCTAssertNotNil(packet.today)
    }

    func testHealthKitDeniedPopulatesMissingDataWithoutCrashing() async {
        healthQuery.workoutsError = HealthKitManagerError.authorizationDenied
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied
        snapshotProvider.snapshot = readySnapshot(on: harness.today)

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .degraded)

        XCTAssertTrue(packet.missingData.healthKitDenied)
        XCTAssertTrue(packet.missingData.stepsUnavailable)
        XCTAssertTrue(packet.missingData.workoutPermissionDeniedOrUnavailable)
        XCTAssertNil(packet.training?.workoutsToday)
        XCTAssertEqual(packet.generationMode, .degraded)
    }

    func testHealthKitUnavailableDistinctFromDenied() async {
        healthQuery.workoutsError = URLError(.notConnectedToInternet)
        healthQuery.stepsError = URLError(.notConnectedToInternet)

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertFalse(packet.missingData.healthKitDenied)
        XCTAssertTrue(packet.missingData.healthKitUnavailable)
        XCTAssertTrue(packet.missingData.workoutsUnavailable)
        XCTAssertNil(packet.training?.workoutsToday)
    }

    // MARK: - Workout semantics

    func testNoWorkoutIsZeroNotUnknown() async {
        healthQuery.workouts = []
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_000
        snapshotProvider.snapshot = readySnapshot(on: harness.today)

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.training?.workoutsToday, 0)
        XCTAssertTrue(packet.training?.workouts.isEmpty == true)
        XCTAssertFalse(packet.missingData.healthKitDenied)
    }

    func testRecoveryMissingSignalsIncludedInHealthIntelligence() async {
        snapshotProvider.snapshot = HealthIntelligenceSnapshot(
            date: harness.today,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery unclear",
                explanation: "Sleep and HRV are missing.",
                recommendedTraining: "Use how you feel today.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_000, activeEnergyKcal: 200, exerciseMinutes: 20),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertTrue(packet.healthIntelligence?.missingSignals.contains("sleep") == true)
        XCTAssertTrue(packet.healthIntelligence?.missingSignals.contains("HRV") == true)
        XCTAssertTrue(packet.missingData.sleepMissing)
        XCTAssertTrue(packet.missingData.hrvMissing)
    }

    func testTrainingLoadPresentWhenEngineReturnsSummary() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)
        trainingLoadEngine.result = TrainingLoadSummary(
            status: .high,
            todayLoad: 92,
            sevenDayLoad: 410,
            twentyEightDayAverageWeeklyLoad: 280,
            loadRatio: 1.46,
            workoutDays7d: 4,
            workoutDays28d: 13,
            explanation: "Training load looks elevated versus your recent baseline.",
            confidence: .moderate,
            missingSignals: []
        )

        let repository = CoachHealthIntelligenceCompositionMockRepository(
            calendar: harness.dateProvider.calendar
        )
        let contextBuilder = HealthIntelligenceContextBuilder(repository: repository)

        let packet = await makeBuilder(
            healthIntelligenceContextBuilder: contextBuilder
        ).makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.training?.trainingLoad, TrainingLoadStatus.high.rawValue)
        XCTAssertEqual(packet.training?.trainingLoadConfidence, .moderate)
        XCTAssertEqual(packet.healthIntelligence?.trainingLoadStatus, TrainingLoadStatus.high.rawValue)
    }

    func testWorkoutCaloriesUseHealthKitNotLegacyDailyLog() async throws {
        try harness.seedWorkoutCaloriesBurned(calories: 500)
        healthQuery.workouts = [
            HealthWorkoutRecord(
                id: UUID(),
                activityName: "Run",
                startDate: harness.today,
                endDate: harness.today.addingTimeInterval(1_800),
                durationMinutes: 30,
                activeCalories: 260
            )
        ]

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.today?.workoutCaloriesBurned?.value, 260)
        XCTAssertNotEqual(packet.today?.workoutCaloriesBurned?.value, 500)
    }

    // MARK: - Photo + meal advice context

    func testPhotoContextIncludesTrainingAndHealthIntelligenceWhenAvailable() async throws {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)
        healthQuery.workouts = [
            HealthWorkoutRecord(
                id: UUID(),
                activityName: "Strength",
                startDate: harness.today,
                endDate: harness.today.addingTimeInterval(2_400),
                durationMinutes: 40,
                activeCalories: 180
            )
        ]

        let context = await makeBuilder().makeContext(
            recentMessages: [],
            currentUserMessage: "Lunch photo"
        )
        let attachment = try makeUploadAttachment()
        let request = try XCTUnwrap(
            CoachMealImageAIRequestBuilder.buildAnalysisRequest(
                attachment: attachment,
                context: context,
                message: "Lunch photo"
            ).successValue
        )

        XCTAssertNotNil(request.context.healthIntelligence)
        XCTAssertEqual(request.context.training?.workoutsToday, 1)
        XCTAssertEqual(request.context.healthIntelligence?.recoveryStatus, RecoveryStatus.moderate.rawValue)
    }

    func testMealAdviceContextIncludesRecoveryAndTrainingWhenAvailable() async throws {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)
        trainingLoadEngine.result = TrainingLoadSummary(
            status: .high,
            todayLoad: 88,
            sevenDayLoad: 390,
            twentyEightDayAverageWeeklyLoad: 260,
            loadRatio: 1.5,
            workoutDays7d: 4,
            workoutDays28d: 12,
            explanation: "Training load looks elevated.",
            confidence: .moderate,
            missingSignals: []
        )
        let repository = CoachHealthIntelligenceCompositionMockRepository(
            calendar: harness.dateProvider.calendar
        )

        let packet = await makeBuilder(
            healthIntelligenceContextBuilder: HealthIntelligenceContextBuilder(repository: repository)
        ).makeContext(recentMessages: [], mode: .live)
        let log = try harness.dailyLogService.getTodayLog()
        let profile = try harness.profileService.getCurrentProfile()

        let message = CoachResponseBuilder.mealAdvice(
            log: log,
            profile: profile,
            hasWorkoutToday: packet.training?.workoutsToday ?? 0 > 0,
            healthIntelligence: packet.healthIntelligence,
            intent: .nutritionAdvice,
            assistantMessage: nil
        )

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertEqual(packet.healthIntelligence?.recoveryStatus, RecoveryStatus.moderate.rawValue)
        XCTAssertEqual(packet.training?.trainingLoad, TrainingLoadStatus.high.rawValue)
        XCTAssertTrue(message.contains("After today's high-demand workout") || message.contains("protein"))
    }

    // MARK: - Helpers

    private func makeBuilder(
        loadHealthIntelligence: Bool? = nil,
        healthIntelligenceContextBuilder: (any HealthIntelligenceContextBuilding)? = nil
    ) -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            userProfileService: harness.profileService,
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: StubHealthKitWorkoutReader(
                    workouts: healthQuery.workouts,
                    error: healthQuery.workoutsError
                ),
                stepReader: StubHealthKitStepReader(
                    stepsByDay: healthQuery.stepsByDay,
                    error: healthQuery.stepsError
                ),
                repositoryReadRoutingEnabled: false
            ),
            healthIntelligenceSnapshotProvider: snapshotProvider,
            healthIntelligenceContextBuilder: healthIntelligenceContextBuilder,
            trainingLoadEngine: trainingLoadEngine,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar,
            loadHealthIntelligence: {
                loadHealthIntelligence ?? HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence
            }
        )
    }

    private func readySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 72,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Sleep was decent.",
                recommendedTraining: "Moderate training is appropriate.",
                recommendedNutrition: "Stay on plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary.mockStrengthWorkout(
                on: day,
                calendar: harness.dateProvider.calendar
            ),
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 420, exerciseMinutes: 35),
            nutritionAdjustment: .mockPostWorkout,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.7, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private func makeUploadAttachment() throws -> CoachMealImageUploadAttachment {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        guard case .success(let processed) = CoachImagePipeline.process(image: image) else {
            throw NSError(domain: "CoachContextHealthIntelligenceDefaultOnTests", code: 1)
        }
        return CoachMealImageUploadAttachment.from(processed: processed)
    }
}

// MARK: - Test doubles

private final class MockCoachHealthIntelligenceSnapshotProvider: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private final class StubCoachTrainingLoadEngine: TrainingLoadProviding, @unchecked Sendable {
    enum TestError: Error {
        case failed
    }

    var result: TrainingLoadSummary = .unknown
    var error: Error?

    func evaluate(_ input: TrainingLoadEngineInput) throws -> TrainingLoadSummary {
        if let error { throw error }
        return result
    }
}

private struct StubHealthKitWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]
    let error: Error?

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        if let error { throw error }
        return workouts.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }
}

private struct StubHealthKitStepReader: HealthKitStepReading {
    let stepsByDay: [Date: Int]
    let error: Error?

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        if let error { throw error }
        guard let steps = stepsByDay[startDate] else {
            throw HealthKitManagerError.authorizationDenied
        }
        return steps
    }
}

private final class CoachHealthIntelligenceCompositionMockRepository: HealthDataRepositorying, @unchecked Sendable {
    let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 28
        )
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}

private extension Result {
    var successValue: Success? {
        if case .success(let value) = self { return value }
        return nil
    }
}
