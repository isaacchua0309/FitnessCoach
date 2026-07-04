//
//  CoachContextPacketV2BuilderTests.swift
//  Fitness CoachTests
//
//  Forma — CoachContextPacketV2Builder assembly tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachContextPacketV2BuilderTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var timelineStore: FakeCoachTimelineStore!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var snapshotProvider: MockCoachContextSnapshotProvider!
    private var timelineRecorder: CapturingCoachTimelineRecorder!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = WeightLogService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            dateProvider: harness.dateProvider
        )
        timelineStore = FakeCoachTimelineStore()
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        snapshotProvider = MockCoachContextSnapshotProvider()
        timelineRecorder = CapturingCoachTimelineRecorder()
    }

    override func tearDown() {
        timelineRecorder = nil
        snapshotProvider = nil
        healthQuery = nil
        timelineStore = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    func testBuildsPacketFromAuthoritativeLogs() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Salad", calories: 420, protein: 28),
            date: harness.today
        )
        _ = try? harness.waterLogService.addWater(amountMl: 500, date: harness.today)
        _ = try? weightLogService.logWeight(68.0, date: harness.today)
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 7_500

        let packet = await makeBuilder().makeContext(
            recentMessages: [
                ChatMessage(role: .user, text: "How am I doing?", createdAt: harness.today)
            ],
            mode: .live
        )

        XCTAssertEqual(packet.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertNotNil(packet.profile)
        XCTAssertNotNil(packet.today)
        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed, 420)
        XCTAssertEqual(packet.today?.hydration?.waterConsumedMl, 500)
        XCTAssertEqual(packet.today?.weight?.weightKg, 68.0)
        XCTAssertEqual(packet.today?.steps?.value, 7_500)
        XCTAssertEqual(packet.recentMealsStructured.count, 1)
        XCTAssertEqual(packet.recentMealsStructured.first?.name, "Salad")
        XCTAssertEqual(packet.recentChatMessages.count, 1)
        XCTAssertNotNil(packet.recentChatMessages.first?.sentAt)
        XCTAssertFalse(packet.missingData.noRecentMeals)
    }

    func testBackfillsTimelineBeforeBuildingContext() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Toast", calories: 180),
            date: harness.today
        )

        let packet = await makeBuilder(includeBackfill: true).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertFalse(packet.timeline.recentEvents.isEmpty)
        XCTAssertTrue(packet.timeline.recentEvents.contains { $0.type == CoachTimelineEventType.foodLogged.rawValue })
        XCTAssertFalse(packet.missingData.noTimelineHistory)
    }

    func testPopulatesCommonFoodsFromHistory() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Oatmeal", calories: 300),
            date: harness.day(offset: -1)
        )
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Oatmeal", calories: 320),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.commonFoods.first?.name, "oatmeal")
        XCTAssertGreaterThanOrEqual(packet.commonFoods.first?.logCount ?? 0, 2)
    }

    func testMissingDataWhenStepsUnavailable() async {
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .degraded)

        XCTAssertTrue(packet.missingData.stepsMissing)
        XCTAssertTrue(packet.missingData.workoutPermissionDeniedOrUnavailable)
        XCTAssertEqual(packet.generationMode, .degraded)
    }

    func testUsesHealthWorkoutCaloriesNotLegacyDailyLogCalories() async throws {
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
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_000

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.today?.workoutCaloriesBurned?.value, 260)
        XCTAssertNotEqual(packet.today?.workoutCaloriesBurned?.value, 500)
    }

    func testIncludesHealthIntelligenceWhenSnapshotAvailable() async {
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)

        let packet = await makeBuilder(loadHealthIntelligence: true).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertTrue(packet.sourceAttribution?.healthIntelligenceIncluded == true)
    }

    func testNilDependenciesDoNotCrash() async {
        let packet = await CoachContextPacketV2Builder().makeContext(
            recentMessages: [],
            mode: .preview
        )

        XCTAssertEqual(packet.generationMode, .preview)
        XCTAssertNil(packet.profile)
        XCTAssertTrue(packet.missingData.noRecentMeals)
        XCTAssertTrue(packet.missingData.noTimelineHistory)
    }

    func testPacketFitsWithinDefaultByteLimit() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Lunch", calories: 650, protein: 40),
            date: harness.today
        )
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 9_000

        let packet = await makeBuilder().makeContext(
            recentMessages: (0..<8).map {
                ChatMessage(role: .assistant, text: String(repeating: "Detail ", count: 20) + "\($0)")
            },
            mode: .live
        )

        XCTAssertTrue(packet.fitsWithinByteLimit())
        XCTAssertLessThanOrEqual(packet.recentChatMessages.count, CoachContextPacketV2Builder.recentChatMessageLimit)
        XCTAssertLessThanOrEqual(packet.timeline.recentEvents.count, CoachContextPacketV2Builder.defaultTimelineEventLimit)
    }

    func testRecordsContextGeneratedWithoutAffectingReturnedTimeline() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 140),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.count, 1)
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.first?.timelineEventCount, packet.timeline.recentEvents.count)
        XCTAssertFalse(packet.timeline.recentEvents.contains { $0.type == CoachTimelineEventType.contextGenerated.rawValue })
    }

    func testTimelineSelectorPrefersTodayConfirmedMutations() {
        let today = "2026-07-03"
        let food = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Salad",
                    calories: 400,
                    proteinGrams: 20,
                    carbsGrams: 30,
                    fatGrams: 12
                )
            ),
            occurredAt: harness.today,
            calendar: harness.dateProvider.calendar
        )
        let system = CoachTimelineEvent.make(
            type: .systemRefresh,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .systemRefresh(SystemRefreshPayload(reason: "refresh")),
            occurredAt: harness.today.addingTimeInterval(-10),
            calendar: harness.dateProvider.calendar
        )

        let selected = CoachContextPacketV2TimelineSelector.selectEvents(
            from: [system, food],
            todayLocalDate: today,
            limit: 1
        )

        XCTAssertEqual(selected.map(\.id), [food.id])
    }

    // MARK: Helpers

    private func makeBuilder(
        includeBackfill: Bool = true,
        loadHealthIntelligence: Bool = false
    ) -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            userProfileService: harness.profileService,
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: StubHealthKitWorkoutReader(workouts: healthQuery.workouts),
                stepReader: StubHealthKitStepReader(
                    stepsByDay: healthQuery.stepsByDay,
                    error: healthQuery.stepsError
                ),
                repositoryReadRoutingEnabled: false
            ),
            healthIntelligenceSnapshotProvider: snapshotProvider,
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
            loadHealthIntelligence: { loadHealthIntelligence }
        )
    }

    private func makeReadySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
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
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 420, exerciseMinutes: 35),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.7, label: "Moderate"),
            nextBestAction: .none
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class CapturingCoachTimelineRecorder: CoachTimelineRecording, @unchecked Sendable {
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
    func recordPendingConfirmationCreated(
        payload: ConfirmationPayload,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        occurredAt: Date?
    ) {}
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

private final class MockCoachContextSnapshotProvider: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private struct StubHealthKitWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        workouts.filter { $0.startDate >= startDate && $0.startDate < endDate }
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
