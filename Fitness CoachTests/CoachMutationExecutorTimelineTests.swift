//
//  CoachMutationExecutorTimelineTests.swift
//  Fitness CoachTests
//
//  Verifies CoachMutationExecutor records structured timeline events after
//  successful persistence and stays resilient when timeline storage fails.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachMutationExecutorTimelineTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var recorder: MutationTimelineCapturingRecorder!
    private var timelineStore: FakeCoachTimelineStore!
    private var executor: CoachMutationExecutor!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        recorder = MutationTimelineCapturingRecorder()
        timelineStore = FakeCoachTimelineStore()
        executor = makeExecutor(recorder: recorder, store: timelineStore)
    }

    override func tearDown() {
        executor = nil
        timelineStore = nil
        recorder = nil
        harness = nil
        super.tearDown()
    }

    // MARK: Food confirm

    func testFoodLogEventAfterPendingConfirmation() throws {
        try harness.seedProfile()

        let pendingId = UUID()
        let confirmation = CoachPendingConfirmation.food(
            AIFoodConfirmationDraft(
                id: pendingId,
                originalText: "log chicken",
                assistantMessage: nil,
                mealDraft: CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft,
                confidence: .high,
                requiresConfirmation: true
            )
        )
        let context = CoachMutationTimelineContext(
            pendingConfirmationId: pendingId,
            sourceAttribution: .estimateFood,
            userEditedBeforeConfirm: true
        )

        let response = awaitBlocking {
            await self.executor.executePendingConfirmation(confirmation, timelineContext: context)
        }

        XCTAssertFalse(response.contains("could not log"))
        XCTAssertEqual(recorder.foodLoggedCalls.count, 1)

        let call = try XCTUnwrap(recorder.foodLoggedCalls.first)
        XCTAssertEqual(call.entry.name, "Chicken breast")
        XCTAssertEqual(call.entry.calories, 330)
        XCTAssertEqual(call.sourceAttribution, .estimateFood)
        XCTAssertTrue(call.userEditedBeforeConfirm)
        XCTAssertEqual(call.entry.quantity, 200)
        XCTAssertEqual(call.entry.unit, "g")
    }

    func testNoFoodLoggedEventWhenMutationFails() {
        let meal = CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft

        let response = executor.executeLogFood(meal)

        XCTAssertTrue(response.contains("could not log"))
        XCTAssertTrue(recorder.foodLoggedCalls.isEmpty)
        XCTAssertEqual(recorder.backendErrors.count, 1)
        XCTAssertEqual(recorder.backendErrors.first?.category, "missing_profile")
    }

    func testDuplicateConfirmDoesNotDuplicateFoodLogged() throws {
        try harness.seedProfile()

        let pendingId = UUID()
        let confirmation = CoachPendingConfirmation.food(
            AIFoodConfirmationDraft(
                id: pendingId,
                originalText: "log chicken",
                assistantMessage: nil,
                mealDraft: CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft,
                confidence: .high,
                requiresConfirmation: true
            )
        )
        let context = CoachMutationTimelineContext(pendingConfirmationId: pendingId)

        let first = awaitBlocking {
            await self.executor.executePendingConfirmation(confirmation, timelineContext: context)
        }
        let second = awaitBlocking {
            await self.executor.executePendingConfirmation(confirmation, timelineContext: context)
        }

        XCTAssertFalse(first.contains("could not log"))
        XCTAssertTrue(second.contains("already logged"))
        XCTAssertEqual(recorder.foodLoggedCalls.count, 1)
    }

    // MARK: Water & weight

    func testWaterLogEventAfterSuccessfulWrite() throws {
        try harness.seedProfile()

        let response = executor.executeLogWater(WaterDraft(amountMl: 350))

        XCTAssertFalse(response.contains("could not save"))
        XCTAssertEqual(recorder.waterLoggedCalls.count, 1)
        XCTAssertEqual(recorder.waterLoggedCalls.first?.entry.amountMl, 350)
        XCTAssertNotNil(recorder.waterLoggedCalls.first?.entry.id)
    }

    func testWeightLogEventAfterSuccessfulWrite() throws {
        try harness.seedProfile()

        let response = executor.executeLogWeight(WeightDraft(weightKg: 71.2, note: nil))

        XCTAssertFalse(response.contains("could not log"))
        XCTAssertEqual(recorder.weightLoggedCalls.count, 1)
        XCTAssertEqual(recorder.weightLoggedCalls.first?.entry.weightKg, 71.2)
        XCTAssertNotNil(recorder.weightLoggedCalls.first?.entry.id)
    }

    // MARK: Edit & delete

    func testFoodEditEventLinksSupersededTimelineEvent() async throws {
        try harness.seedProfile()

        let meal = CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft
        let logged = try harness.actionCenter.logFood(meal, date: harness.today)
        let priorEventId = UUID()
        let baseEvent = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: logged.id,
                    dailyLogId: logged.dailyLogId,
                    mealType: logged.mealType?.rawValue,
                    name: logged.name,
                    calories: logged.calories
                )
            ),
            occurredAt: harness.today,
            calendar: Calendar.current,
            link: CoachTimelineEventLink(linkedEntryId: logged.id, linkedDailyLogId: logged.dailyLogId)
        )
        let priorEvent = CoachTimelineEvent(
            id: priorEventId,
            type: baseEvent.type,
            source: baseEvent.source,
            sourceAttribution: baseEvent.sourceAttribution,
            confidence: baseEvent.confidence,
            status: baseEvent.status,
            payload: baseEvent.payload,
            utcTimestamp: baseEvent.utcTimestamp,
            localTimestamp: baseEvent.localTimestamp,
            timezoneIdentifier: baseEvent.timezoneIdentifier,
            localDate: baseEvent.localDate,
            link: baseEvent.link,
            supersedesEventId: baseEvent.supersedesEventId,
            recordedAt: baseEvent.recordedAt
        )
        try await timelineStore.append(priorEvent)

        let editDraft = FoodDraft(
            mealType: .lunch,
            name: "Grilled chicken",
            quantity: 200,
            unit: "g",
            calories: 340,
            protein: 64,
            carbs: 0,
            fat: 8,
            fiber: nil,
            sodium: nil,
            source: .corrected,
            confidence: .high,
            imageUrl: nil,
            notes: nil
        )
        let action = AICommandAction(type: .editEntry, foodDraft: editDraft)

        let response = await executor.executeEditAction(action)

        XCTAssertFalse(response.contains("could not edit"))
        XCTAssertEqual(recorder.foodEditedCalls.count, 1)
        XCTAssertEqual(recorder.foodEditedCalls.first?.entry.name, "Grilled chicken")
        XCTAssertEqual(recorder.foodEditedCalls.first?.supersedesEventId, priorEventId)
    }

    func testFoodDeleteEventLinksSupersededTimelineEvent() async throws {
        try harness.seedProfile()

        let meal = CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft
        let logged = try harness.actionCenter.logFood(meal, date: harness.today)
        let priorEventId = UUID()
        let baseEvent = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: logged.id,
                    dailyLogId: logged.dailyLogId,
                    mealType: MealType.lunch.rawValue,
                    name: logged.name,
                    calories: logged.calories
                )
            ),
            occurredAt: harness.today,
            calendar: Calendar.current,
            link: CoachTimelineEventLink(linkedEntryId: logged.id, linkedDailyLogId: logged.dailyLogId)
        )
        let priorEvent = CoachTimelineEvent(
            id: priorEventId,
            type: baseEvent.type,
            source: baseEvent.source,
            sourceAttribution: baseEvent.sourceAttribution,
            confidence: baseEvent.confidence,
            status: baseEvent.status,
            payload: baseEvent.payload,
            utcTimestamp: baseEvent.utcTimestamp,
            localTimestamp: baseEvent.localTimestamp,
            timezoneIdentifier: baseEvent.timezoneIdentifier,
            localDate: baseEvent.localDate,
            link: baseEvent.link,
            supersedesEventId: baseEvent.supersedesEventId,
            recordedAt: baseEvent.recordedAt
        )
        try await timelineStore.append(priorEvent)

        let action = AICommandAction(
            type: .deleteEntry,
            foodDraft: FoodDraft(
                mealType: .lunch,
                name: logged.name,
                quantity: nil,
                unit: nil,
                calories: logged.calories,
                protein: logged.protein,
                carbs: logged.carbs,
                fat: logged.fat,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil
            )
        )

        let response = await executor.executeDeleteAction(action)

        XCTAssertFalse(response.contains("could not delete"))
        XCTAssertEqual(recorder.foodDeletedCalls.count, 1)
        XCTAssertEqual(recorder.foodDeletedCalls.first?.entry.id, logged.id)
        XCTAssertEqual(recorder.foodDeletedCalls.first?.supersedesEventId, priorEventId)
    }

    // MARK: Timeline store resilience

    func testTimelineStoreFailureDoesNotFailMutation() async throws {
        try harness.seedProfile()
        timelineStore.injectedAppendError = CoachTimelineStoreError.invalidDateRange

        let resilientRecorder = DefaultCoachTimelineRecorder(store: timelineStore)
        let resilientExecutor = makeExecutor(recorder: resilientRecorder, store: timelineStore)
        let meal = CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft

        let response = resilientExecutor.executeLogFood(meal)

        XCTAssertFalse(response.contains("could not log"))
        let entries = try harness.actionCenter.getFoodEntries(for: harness.today)
        XCTAssertEqual(entries.count, 1)

        try await waitForTimelineAppendAttempts(atLeast: 1)
    }

    private func waitForTimelineAppendAttempts(atLeast count: Int) async throws {
        let satisfied = await AsyncTestSupport.waitUntil(maxYields: 100) {
            self.timelineStore.appendAttempts >= count
        }
        if !satisfied {
            throw NSError(
                domain: "CoachMutationExecutorTimelineTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for timeline append"]
            )
        }
    }

    // MARK: Helpers

    private func makeExecutor(
        recorder: any CoachTimelineRecording,
        store: FakeCoachTimelineStore?
    ) -> CoachMutationExecutor {
        CoachMutationExecutor(
            actionCenter: harness.actionCenter,
            dailyLogReader: harness.dailyLogService,
            healthActivityQuery: harness.healthActivityQuery,
            mutationHistory: CoachMutationHistory(),
            timelineRecorder: recorder,
            timelineStore: store
        )
    }

    private func awaitBlocking<T>(_ operation: @escaping () async -> T) -> T {
        let expectation = expectation(description: "async")
        var value: T!
        Task {
            value = await operation()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        return value
    }
}

// MARK: - Capturing recorder

@MainActor
private final class MutationTimelineCapturingRecorder: CoachTimelineRecording, @unchecked Sendable {

    struct FoodLoggedCall {
        let entry: FoodEntry
        let sourceAttribution: CoachTimelineEventSourceAttribution
        let userEditedBeforeConfirm: Bool
    }

    struct FoodEditedCall {
        let entry: FoodEntry
        let supersedesEventId: UUID?
    }

    struct FoodDeletedCall {
        let entry: FoodEntry
        let supersedesEventId: UUID?
    }

    struct BackendErrorCall {
        let category: String
        let userMessage: String?
    }

    private(set) var foodLoggedCalls: [FoodLoggedCall] = []
    private(set) var waterLoggedCalls: [(entry: WaterEntry, occurredAt: Date?)] = []
    private(set) var weightLoggedCalls: [(entry: WeightEntry, occurredAt: Date?)] = []
    private(set) var foodEditedCalls: [FoodEditedCall] = []
    private(set) var foodDeletedCalls: [FoodDeletedCall] = []
    private(set) var backendErrors: [BackendErrorCall] = []

    func recordUserMessage(text: String, messageId: UUID?, hasPhotoAttachment: Bool, occurredAt: Date?) {}
    func recordAssistantMessage(text: String, messageId: UUID?, sourceAttribution: CoachTimelineEventSourceAttribution, occurredAt: Date?) {}
    func recordFoodEstimateCreated(payload: FoodEstimatePayload, source: CoachTimelineEventSource, sourceAttribution: CoachTimelineEventSourceAttribution, confidence: CoachTimelineEventConfidence?, status: CoachTimelineEventStatus, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}

    func recordFoodLogged(
        entry: FoodEntry,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        userEditedBeforeConfirm: Bool,
        occurredAt: Date?
    ) {
        foodLoggedCalls.append(
            FoodLoggedCall(
                entry: entry,
                sourceAttribution: sourceAttribution,
                userEditedBeforeConfirm: userEditedBeforeConfirm
            )
        )
    }

    func recordFoodRejected(payload: FoodEstimatePayload, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordWaterLogged(entry: WaterEntry, occurredAt: Date?) {
        waterLoggedCalls.append((entry, occurredAt))
    }
    func recordWeightLogged(entry: WeightEntry, occurredAt: Date?) {
        weightLoggedCalls.append((entry, occurredAt))
    }

    func recordFoodEdited(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {
        foodEditedCalls.append(FoodEditedCall(entry: entry, supersedesEventId: supersedesEventId))
    }

    func recordFoodDeleted(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {
        foodDeletedCalls.append(FoodDeletedCall(entry: entry, supersedesEventId: supersedesEventId))
    }

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

    func recordBackendError(
        category: String,
        userMessage: String?,
        isRetryable: Bool,
        httpStatus: Int?,
        occurredAt: Date?
    ) {
        backendErrors.append(BackendErrorCall(category: category, userMessage: userMessage))
    }

    func recordAuthError(userMessage: String?, occurredAt: Date?) {}
    func recordHealthDataUnavailable(missingSignals: [String], reason: String?, healthIntelligenceAwarenessAvailable: Bool?, occurredAt: Date?) {}
    func recordContextGenerated(payload: ContextGenerationPayload, occurredAt: Date?) {}
}
