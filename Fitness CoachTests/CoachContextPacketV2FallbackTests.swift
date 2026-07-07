//
//  CoachContextPacketV2FallbackTests.swift
//  Fitness CoachTests
//
//  Forma — Safe fallback when CoachContextPacketV2 assembly fails.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachContextPacketV2FallbackTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var timelineStore: FakeCoachTimelineStore!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var timelineRecorder: CapturingFallbackTimelineRecorder!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = harness.weightLogService
        timelineStore = FakeCoachTimelineStore()
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        timelineRecorder = CapturingFallbackTimelineRecorder()
    }

    override func tearDown() {
        timelineRecorder = nil
        healthQuery = nil
        timelineStore = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    func testTimelineStoreThrowProducesFallbackPacket() async {
        timelineStore.injectedLoadError = CoachTimelineStoreError.eventNotFound(UUID())
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 5_000

        let packet = await makeBuilder().makeContext(
            recentMessages: [],
            currentUserMessage: "Hello",
            mode: .live
        )

        assertFallbackPacket(packet)
        XCTAssertEqual(packet.currentUserMessage, "Hello")
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.count, 0)
    }

    func testDailyLogServiceThrowProducesFallbackPacket() async {
        let throwingDailyLog = ThrowingDailyLogReader(
            underlying: harness.dailyLogService,
            getTodayLogError: ServiceError.dailyLogNotFound
        )
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_000

        let packet = await makeBuilder(dailyLogService: throwingDailyLog).makeContext(
            recentMessages: [],
            mode: .live
        )

        assertFallbackPacket(packet)
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.count, 1)
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.last?.trigger, CoachContextGenerationMode.degraded.rawValue)
    }

    func testFoodLogServiceThrowProducesFallbackPacket() async {
        let throwingFoodLog = ThrowingFoodLogReader(
            underlying: harness.foodLogService,
            getFoodEntriesError: ServiceError.dailyLogNotFound
        )
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_000

        let packet = await makeBuilder(foodLogService: throwingFoodLog).makeContext(
            recentMessages: [],
            mode: .live
        )

        assertFallbackPacket(packet)
        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertNil(packet.training)
    }

    func testHealthQueryThrowProducesFallbackPacket() async {
        healthQuery.stepsError = NSError(domain: "test", code: 42)

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        assertFallbackPacket(packet)
        XCTAssertNil(packet.today?.steps)
    }

    func testCorruptedEventPayloadDoesNotCrash() async {
        let corrupt = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .empty,
            occurredAt: harness.today,
            calendar: harness.dateProvider.calendar
        )
        timelineStore.seedEventsForTests([corrupt])
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 3_000

        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertEqual(packet.generationMode, .live)
        XCTAssertTrue(packet.timeline.recentEvents.isEmpty)
    }

    func testProfileMissingStillBuildsFallback() async {
        let throwingDailyLog = ThrowingDailyLogReader(
            underlying: harness.dailyLogService,
            getTodayLogError: ServiceError.dailyLogNotFound
        )

        let packet = await makeBuilder(
            dailyLogService: throwingDailyLog,
            userProfileService: nil
        ).makeContext(recentMessages: [], mode: .live)

        assertFallbackPacket(packet)
        XCTAssertNil(packet.profile)
    }

    func testFallbackPacketEncodes() async throws {
        timelineStore.injectedLoadError = CoachTimelineStoreError.eventNotFound(UUID())

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)
        let data = try packet.encodedJSONData()
        let decoded = try JSONDecoder().decode(CoachContextPacketV2.self, from: data)

        XCTAssertTrue(decoded.missingData.contextGenerationFailed)
        XCTAssertEqual(decoded.generationMode, .degraded)
        XCTAssertEqual(decoded.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
    }

    func testBackendRequestStillSendsV2SchemaVersion() async throws {
        timelineStore.injectedLoadError = CoachTimelineStoreError.eventNotFound(UUID())
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 6_000

        let packet = await makeBuilder().makeContext(
            recentMessages: [],
            currentUserMessage: "How am I doing?"
        )

        let request = AICoachIntentClassificationRequest(
            text: "How am I doing?",
            context: packet,
            modelName: CoachModelConfig.default.cheapClassifierModel,
            modelConfig: .default
        )

        XCTAssertEqual(request.context.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        let json = try request.context.encodedJSONData()
        XCTAssertFalse(json.isEmpty)
    }

    func testContextDegradationDoesNotSurfaceUserFacingBackendError() async {
        timelineStore.injectedLoadError = CoachTimelineStoreError.eventNotFound(UUID())

        let packet = await makeBuilder().makeContext(
            recentMessages: [ChatMessage(role: .user, text: "Hi", createdAt: harness.today)],
            currentUserMessage: "Hi",
            mode: .live
        )

        XCTAssertTrue(packet.missingData.contextGenerationFailed)
        XCTAssertNotEqual(CoachResponseBuilder.backendUnavailableResponse, packet.assumptions.first?.detail)
    }

    func testFallbackOmitsInventedStepsWorkoutsAndMeals() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Salad", calories: 420),
            date: harness.today
        )
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
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 8_000
        timelineStore.injectedLoadError = CoachTimelineStoreError.eventNotFound(UUID())

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        assertFallbackPacket(packet)
        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertNil(packet.today?.steps)
        XCTAssertNil(packet.training)
        XCTAssertTrue(packet.timeline.recentEvents.isEmpty)
    }

    // MARK: Helpers

    private func assertFallbackPacket(_ packet: CoachContextPacketV2) {
        XCTAssertEqual(packet.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertEqual(packet.generationMode, .degraded)
        XCTAssertTrue(packet.missingData.contextGenerationFailed)
        XCTAssertTrue(packet.assumptions.contains { $0.key == "contextGeneration" })
        XCTAssertTrue(packet.assumptions.contains { $0.key == "degradedMode" })
        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertTrue(packet.commonFoods.isEmpty)
        XCTAssertTrue(packet.timeline.recentEvents.isEmpty)
        XCTAssertNil(packet.training)
        XCTAssertNil(packet.healthIntelligence)
    }

    private func makeBuilder(
        includeBackfill: Bool = false,
        dailyLogService: (any DailyLogReading)? = nil,
        foodLogService: (any FoodLogReading)? = nil,
        userProfileService: (any UserProfileReading)? = nil
    ) -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: dailyLogService ?? harness.dailyLogService,
            foodLogService: foodLogService ?? harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            userProfileService: userProfileService ?? harness.profileService,
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: StubFallbackHealthKitWorkoutReader(
                    workouts: healthQuery.workouts,
                    error: healthQuery.workoutsError
                ),
                stepReader: StubFallbackHealthKitStepReader(
                    stepsByDay: healthQuery.stepsByDay,
                    error: healthQuery.stepsError
                ),
                repositoryReadRoutingEnabled: false
            ),
            timelineStore: timelineStore,
            timelineBackfillService: includeBackfill
                ? CoachTimelineBackfillService(
                    timelineStore: timelineStore,
                    foodLogService: harness.foodLogService,
                    waterLogService: harness.waterLogService,
                    weightLogService: weightLogService,
                    healthActivityQuery: healthQuery,
                    dateProvider: harness.dateProvider,
                    calendar: harness.dateProvider.calendar
                )
                : nil,
            timelineRecorder: timelineRecorder,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar,
            loadHealthIntelligence: { false }
        )
    }
}

// MARK: - Throwing readers

@MainActor
private final class ThrowingDailyLogReader: DailyLogReading {
    let underlying: DailyLogReading
    var getTodayLogError: Error?

    init(underlying: DailyLogReading, getTodayLogError: Error? = nil) {
        self.underlying = underlying
        self.getTodayLogError = getTodayLogError
    }

    func getTodayLog() throws -> DailyLog {
        if let getTodayLogError { throw getTodayLogError }
        return try underlying.getTodayLog()
    }

    func getLog(for date: Date) throws -> DailyLog? {
        try underlying.getLog(for: date)
    }

    func getLogs(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
        try underlying.getLogs(from: startDate, to: endDate)
    }

    @discardableResult
    func ensureTodayLog() throws -> DailyLog {
        try underlying.ensureTodayLog()
    }
}

@MainActor
private final class ThrowingFoodLogReader: FoodLogReading {
    let underlying: FoodLogReading
    var getFoodEntriesError: Error?

    init(underlying: FoodLogReading, getFoodEntriesError: Error? = nil) {
        self.underlying = underlying
        self.getFoodEntriesError = getFoodEntriesError
    }

    func getFoodEntries(for date: Date) throws -> [FoodEntry] {
        if let getFoodEntriesError { throw getFoodEntriesError }
        return try underlying.getFoodEntries(for: date)
    }

    func getFoodEntries(from startDate: Date, to endDate: Date, calendar: Calendar) throws -> [FoodEntry] {
        try underlying.getFoodEntries(from: startDate, to: endDate, calendar: calendar)
    }
}

@MainActor
private final class CapturingFallbackTimelineRecorder: CoachTimelineRecording, @unchecked Sendable {
    private(set) var contextGeneratedPayloads: [ContextGenerationPayload] = []

    func recordUserMessage(text: String, messageId: UUID?, hasPhotoAttachment: Bool, occurredAt: Date?) {}
    func recordAssistantMessage(text: String, messageId: UUID?, sourceAttribution: CoachTimelineEventSourceAttribution, occurredAt: Date?) {}
    func recordFoodEstimateCreated(payload: FoodEstimatePayload, source: CoachTimelineEventSource, sourceAttribution: CoachTimelineEventSourceAttribution, confidence: CoachTimelineEventConfidence?, status: CoachTimelineEventStatus, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordFoodLogged(entry: FoodEntry, sourceAttribution: CoachTimelineEventSourceAttribution, userEditedBeforeConfirm: Bool, linkedPhotoSessionId: UUID?, occurredAt: Date?) {}
    func recordFoodRejected(payload: FoodEstimatePayload, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordFoodEdited(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {}
    func recordFoodDeleted(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {}
    func recordWaterLogged(entry: WaterEntry, occurredAt: Date?) {}
    func recordWeightLogged(entry: WeightEntry, occurredAt: Date?) {}
    func recordWorkoutDetected(workoutCount: Int, totalDurationMinutes: Int, totalActiveCalories: Int?, primaryWorkoutTitle: String?, demand: String?, occurredAt: Date?) {}
    func recordStepsUpdated(steps: Int, previousSteps: Int?, occurredAt: Date?) {}
    func recordPhotoAttached(payload: PhotoPayload, messageId: UUID?, occurredAt: Date?) {}
    func recordPhotoAnalysisStarted(sessionId: UUID, messageId: UUID?, occurredAt: Date?) {}
    func recordPhotoAnalysisCompleted(sessionId: UUID, messageId: UUID?, mealName: String?, estimateId: UUID?, confidence: CoachTimelineEventConfidence?, occurredAt: Date?) {}
    func recordPhotoAnalysisFailed(sessionId: UUID, messageId: UUID?, errorCategory: String, userMessage: String?, isRetryable: Bool, occurredAt: Date?) {}
    func recordClarificationAsked(question: String, messageId: UUID?, sessionId: UUID, occurredAt: Date?) {}
    func recordClarificationAnswered(answer: String, messageId: UUID?, sessionId: UUID, occurredAt: Date?) {}
    func recordPendingConfirmationCreated(payload: ConfirmationPayload, sourceAttribution: CoachTimelineEventSourceAttribution, occurredAt: Date?) {}
    func recordPendingConfirmationConfirmed(payload: ConfirmationPayload, entryId: UUID?, occurredAt: Date?) {}
    func recordPendingConfirmationRejected(payload: ConfirmationPayload, occurredAt: Date?) {}
    func recordUndoPerformed(entryType: String, undoneEntryId: UUID?, summary: String?, occurredAt: Date?) {}
    func recordBackendError(category: String, userMessage: String?, isRetryable: Bool, httpStatus: Int?, occurredAt: Date?) {}
    func recordAuthError(userMessage: String?, occurredAt: Date?) {}
    func recordHealthDataUnavailable(missingSignals: [String], reason: String?, healthIntelligenceAwarenessAvailable: Bool?, occurredAt: Date?) {}
    func recordContextGenerated(payload: ContextGenerationPayload, occurredAt: Date?) {
        contextGeneratedPayloads.append(payload)
    }
}

private struct StubFallbackHealthKitWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]
    let error: Error?

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        if let error { throw error }
        return workouts.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }
}

private struct StubFallbackHealthKitStepReader: HealthKitStepReading {
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
