//
//  CoachContextHealthIntelligenceHardeningTests.swift
//  Fitness CoachTests
//
//  Verifies bounded Health Intelligence loading and safe Coach send-path degradation.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachContextHealthIntelligenceHardeningTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var snapshotProvider: ConfigurableCoachHealthIntelligenceSnapshotProvider!
    private var trainingLoadEngine: StubCoachHIHardeningTrainingLoadEngine!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = harness.weightLogService
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        snapshotProvider = ConfigurableCoachHealthIntelligenceSnapshotProvider()
        trainingLoadEngine = StubCoachHIHardeningTrainingLoadEngine()
    }

    override func tearDown() {
        trainingLoadEngine = nil
        snapshotProvider = nil
        healthQuery = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    // MARK: - Health Intelligence load outcomes

    func testHealthIntelligenceSuccessWithinTimeout() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)
        snapshotProvider.loadDelay = .milliseconds(10)

        let packet = await makeBuilder(
            healthIntelligenceLoadTimeout: .milliseconds(200)
        ).makeContext(recentMessages: [], mode: .live)

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertEqual(packet.healthIntelligence?.recoveryStatus, RecoveryStatus.moderate.rawValue)
        XCTAssertFalse(packet.missingData.healthIntelligenceTimedOut)
        XCTAssertFalse(packet.missingData.healthIntelligenceFailed)
        XCTAssertEqual(packet.generationMode, .live)
    }

    func testHealthIntelligenceTimeoutContinuesWithBasicHealthContext() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)
        snapshotProvider.loadDelay = .milliseconds(500)
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 6_500
        healthQuery.workouts = [
            HealthWorkoutRecord(
                id: UUID(),
                activityName: "Run",
                startDate: harness.today,
                endDate: harness.today.addingTimeInterval(1_800),
                durationMinutes: 30,
                activeCalories: 220
            )
        ]

        let packet = await makeBuilder(
            healthIntelligenceLoadTimeout: .milliseconds(50)
        ).makeContext(recentMessages: [], mode: .live)

        XCTAssertTrue(packet.missingData.healthIntelligenceTimedOut)
        XCTAssertFalse(packet.missingData.healthIntelligenceFailed)
        XCTAssertEqual(packet.healthIntelligence?.healthContextStatus, .unavailable)
        XCTAssertEqual(packet.today?.steps?.value, 6_500)
        XCTAssertEqual(packet.training?.workoutsToday, 1)
        XCTAssertEqual(packet.generationMode, .degraded)
        XCTAssertTrue(
            packet.assumptions.contains {
                $0.key == "health_intelligence_unavailable" && $0.detail.contains("timed out")
            }
        )
    }

    func testHealthIntelligenceThrownErrorFallsBackToBasicHealthContext() async {
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 3_200

        let packet = await makeBuilder(
            healthIntelligenceSnapshotLoad: { _, _ in
                .failed(reason: "simulated_failure")
            }
        ).makeContext(recentMessages: [], mode: .live)

        XCTAssertFalse(packet.missingData.healthIntelligenceTimedOut)
        XCTAssertTrue(packet.missingData.healthIntelligenceFailed)
        XCTAssertEqual(packet.healthIntelligence?.healthContextStatus, .unavailable)
        XCTAssertEqual(packet.today?.steps?.value, 3_200)
        XCTAssertEqual(packet.generationMode, .degraded)
        XCTAssertTrue(
            packet.assumptions.contains {
                $0.key == "health_intelligence_unavailable" && $0.detail.contains("failed")
            }
        )
    }

    // MARK: - HealthKit availability matrix

    func testHealthKitUnavailableBuildsDegradedPacket() async {
        snapshotProvider.snapshot = readySnapshot(on: harness.today)

        let packet = await makeBuilder(
            healthActivityQuery: nil
        ).makeContext(recentMessages: [], mode: .live)

        XCTAssertTrue(packet.missingData.healthKitUnavailable)
        XCTAssertTrue(packet.missingData.stepsUnavailable)
        XCTAssertTrue(packet.missingData.workoutsUnavailable)
        XCTAssertNil(packet.today?.steps)
        XCTAssertEqual(packet.generationMode, .degraded)
    }

    func testOnlyStepsAvailableWhenWorkoutsMissing() async {
        snapshotProvider.snapshot = nil
        healthQuery.workouts = []
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 9_100

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.today?.steps?.value, 9_100)
        XCTAssertEqual(packet.training?.workoutsToday, 0)
        XCTAssertTrue(packet.training?.workouts.isEmpty == true)
    }

    func testOnlyWorkoutsAvailableWhenStepsMissing() async {
        snapshotProvider.snapshot = nil
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
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertNil(packet.today?.steps)
        XCTAssertEqual(packet.training?.workoutsToday, 1)
        XCTAssertTrue(packet.missingData.stepsUnavailable)
        XCTAssertFalse(packet.missingData.workoutsUnavailable)
    }

    func testNoHealthDataStillBuildsValidPacket() async {
        snapshotProvider.snapshot = nil
        healthQuery.workouts = []
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied
        healthQuery.workoutsError = HealthKitManagerError.authorizationDenied

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertNotNil(packet.meta)
        XCTAssertNotNil(packet.today)
        XCTAssertNil(packet.today?.steps)
        XCTAssertTrue(packet.missingData.healthKitDenied)
        XCTAssertEqual(packet.generationMode, .degraded)
    }

    // MARK: - Validation

    func testPacketValidAfterHealthIntelligenceFallback() async {
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_000

        let packet = await makeBuilder(
            healthIntelligenceSnapshotLoad: { _, _ in .timedOut }
        ).makeContext(recentMessages: [], mode: .live)

        XCTAssertTrue(packet.fitsWithinByteLimit())
        XCTAssertTrue(packet.missingData.healthIntelligenceTimedOut)
        XCTAssertNotNil(packet.today)
    }

    func testValidatorAcceptsDegradedHealthIntelligencePacket() async {
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 5_500

        let packet = await makeBuilder(
            healthIntelligenceSnapshotLoad: { _, _ in .failed(reason: "simulated_failure") }
        ).makeContext(recentMessages: [], mode: .live)

        let validation = CoachContextCorrectnessValidator.validateAndCorrect(
            packet,
            calendar: harness.dateProvider.calendar
        )

        XCTAssertTrue(validation.isValid)
        XCTAssertFalse(validation.correctedPacket.missingData.healthIntelligenceFailed == false)
        XCTAssertEqual(validation.correctedPacket.generationMode, .degraded)
    }

    // MARK: - Helpers

    private func makeBuilder(
        healthActivityQuery: HealthActivityQueryService? = nil,
        healthIntelligenceLoadTimeout: Duration = CoachHealthIntelligenceSnapshotLoader.defaultTimeout,
        healthIntelligenceSnapshotLoad: (@Sendable (_ date: Date, _ calendar: Calendar) async -> CoachHealthIntelligenceSnapshotLoadOutcome)? = nil
    ) -> CoachContextPacketV2Builder {
        let resolvedHealthQuery = healthActivityQuery ?? HealthActivityQueryService(
            workoutReader: StubCoachHIHardeningWorkoutReader(
                workouts: healthQuery.workouts,
                error: healthQuery.workoutsError
            ),
            stepReader: StubCoachHIHardeningStepReader(
                stepsByDay: healthQuery.stepsByDay,
                error: healthQuery.stepsError
            ),
            repositoryReadRoutingEnabled: false
        )

        return CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            userProfileService: harness.profileService,
            healthActivityQuery: resolvedHealthQuery,
            healthIntelligenceSnapshotProvider: snapshotProvider,
            trainingLoadEngine: trainingLoadEngine,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar,
            healthIntelligenceLoadTimeout: healthIntelligenceLoadTimeout,
            healthIntelligenceSnapshotLoad: healthIntelligenceSnapshotLoad
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
}

// MARK: - Test doubles

private final class ConfigurableCoachHealthIntelligenceSnapshotProvider: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?
    var loadDelay: Duration = .zero

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        if loadDelay > .zero {
            try? await Task.sleep(for: loadDelay)
        }
        return snapshot
    }
}

private final class StubCoachHIHardeningTrainingLoadEngine: TrainingLoadProviding, @unchecked Sendable {
    func evaluate(_ input: TrainingLoadEngineInput) throws -> TrainingLoadSummary {
        .unknown
    }
}

private struct StubCoachHIHardeningWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]
    let error: Error?

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        if let error { throw error }
        return workouts.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }
}

private struct StubCoachHIHardeningStepReader: HealthKitStepReading {
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
