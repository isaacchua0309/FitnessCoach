//
//  CoachV2ResponseHandlingTests.swift
//  Fitness CoachTests
//
//  Verifies CoachContextPacketV2-aware response handling on iOS.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachV2ResponseHandlingTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var recorder: MutationTimelineCapturingRecorder!
    private var executor: CoachMutationExecutor!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        recorder = MutationTimelineCapturingRecorder()
        executor = CoachMutationExecutor(
            actionCenter: harness.actionCenter,
            dailyLogReader: harness.dailyLogService,
            healthActivityQuery: harness.healthActivityQuery,
            mutationHistory: CoachMutationHistory(),
            timelineRecorder: recorder
        )
    }

    override func tearDown() {
        executor = nil
        recorder = nil
        harness = nil
        super.tearDown()
    }

    // MARK: Advice uses v2 context

    func testMealAdviceAppendsMissingDataDisclaimerFromV2Context() throws {
        try harness.seedProfile()
        let log = try harness.dailyLogService.getTodayLog()
        var missing = CoachMissingDataContext()
        missing.stepsUnavailable = true
        missing.workoutsUnavailable = true
        let hints = CoachResponseContextHints(missingData: missing)

        let message = CoachResponseBuilder.mealAdvice(
            log: log,
            profile: try harness.profileService.getCurrentProfile(),
            hasWorkoutToday: false,
            healthIntelligence: nil,
            intent: .nutritionAdvice,
            assistantMessage: "Keep your next meal protein-forward.",
            contextHints: hints
        )

        XCTAssertTrue(message.contains("protein-forward"))
        XCTAssertTrue(message.contains("Steps aren't available"))
        XCTAssertTrue(message.contains("Workout data isn't available"))
    }

    // MARK: Food estimate source attribution

    func testFoodEstimateSourceAttributionMapping() {
        XCTAssertEqual(
            CoachAIResponseContextAdapter.resolveFoodEstimateAttribution(
                fromPhotoAnalysis: false,
                usedClassifierMerge: false,
                matchedCommonFood: false,
                isLocalEstimate: true
            ),
            .localParser
        )
        XCTAssertEqual(
            CoachAIResponseContextAdapter.resolveFoodEstimateAttribution(
                fromPhotoAnalysis: false,
                usedClassifierMerge: true,
                matchedCommonFood: false,
                isLocalEstimate: false
            ),
            .classifier
        )
        XCTAssertEqual(
            CoachAIResponseContextAdapter.resolveFoodEstimateAttribution(
                fromPhotoAnalysis: false,
                usedClassifierMerge: false,
                matchedCommonFood: false,
                isLocalEstimate: false
            ),
            .estimateFood
        )
        XCTAssertEqual(
            CoachAIResponseContextAdapter.resolveFoodEstimateAttribution(
                fromPhotoAnalysis: true,
                usedClassifierMerge: false,
                matchedCommonFood: false,
                isLocalEstimate: false
            ),
            .mealImage
        )
        XCTAssertEqual(
            CoachAIResponseContextAdapter.resolveFoodEstimateAttribution(
                fromPhotoAnalysis: false,
                usedClassifierMerge: false,
                matchedCommonFood: true,
                isLocalEstimate: false
            ),
            .commonFoodReference
        )
    }

    func testFoodPendingPreservesSourceAttribution() {
        let result = CoachPendingConfirmationPresenter.presentFoodPending(
            originalText: "same as usual chicken rice",
            assistantMessage: nil,
            mealDraft: CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft,
            confidence: .medium,
            sourceAttribution: .commonFoodReference
        )

        guard let confirmation = result.pendingConfirmation,
              case .food(let draft) = confirmation else {
            return XCTFail("Expected food pending confirmation")
        }
        XCTAssertEqual(draft.sourceAttribution, .commonFoodReference)
    }

    // MARK: Edit/delete linked entry mapping

    func testDeleteActionUsesLinkedEntryId() async throws {
        try harness.seedProfile()

        let meal = CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft
        let logged = try harness.actionCenter.logFood(meal, date: harness.today)

        let action = AICommandAction(
            type: .deleteEntry,
            targetEntrySelector: logged.id.uuidString,
            linkedEntryId: logged.id
        )

        let response = await executor.executeDeleteAction(action)

        XCTAssertFalse(response.contains("could not delete"))
        XCTAssertEqual(recorder.foodDeletedCalls.count, 1)
        XCTAssertEqual(recorder.foodDeletedCalls.first?.entry.id, logged.id)
    }

    func testEnrichActionMapsSelectorUUIDToLinkedEntryId() {
        let entryId = UUID()
        let context = CoachContextPacketV2(
            meta: CoachContextMeta.make(),
            timeline: CoachContextTimelinePacket(
                recentEvents: [
                    CoachTimelineContextEvent(
                        id: UUID(),
                        timestamp: Date(),
                        type: CoachTimelineEventType.foodLogged.rawValue,
                        source: CoachTimelineEventSourceAttribution.estimateFood.rawValue,
                        status: CoachTimelineEventStatus.confirmed.rawValue,
                        summary: "Chicken breast",
                        linkedEntryId: entryId
                    )
                ]
            ),
            recentMealsStructured: [
                CoachRecentMealContext(
                    name: "Chicken breast",
                    linkedEntryId: entryId
                )
            ]
        )

        let action = AICommandAction(
            type: .deleteEntry,
            targetEntrySelector: entryId.uuidString
        )
        let enriched = CoachEntryReferenceResolver.enrichAction(
            action,
            context: context
        ).enrichedAction

        XCTAssertEqual(enriched?.linkedEntryId, entryId)
        XCTAssertNotNil(enriched?.linkedTimelineEventId)
    }

    func testEditDeleteConfirmationPayloadIncludesLinkedEntryId() {
        let entryId = UUID()
        let timelineEventId = UUID()
        let action = AICommandAction(
            type: .deleteEntry,
            targetEntrySelector: entryId.uuidString,
            linkedEntryId: entryId,
            linkedTimelineEventId: timelineEventId
        )
        let payload = CoachModelTimelineSupport.confirmationPayload(
            from: .delete(action, originalText: "delete lunch", assistantMessage: "Delete chicken?")
        )

        XCTAssertEqual(payload.linkedEntryId, entryId)
        XCTAssertEqual(payload.relatedTimelineEventId, timelineEventId)
    }

    // MARK: Missing steps does not invent steps

    func testStatusWithMissingStepsDoesNotInventStepCount() throws {
        try harness.seedProfile()
        let log = try harness.dailyLogService.getTodayLog()
        var missing = CoachMissingDataContext()
        missing.stepsUnavailable = true
        let hints = CoachResponseContextHints(missingData: missing)

        let message = CoachResponseBuilder.status(
            log,
            healthIntelligence: nil,
            contextHints: hints
        )

        XCTAssertTrue(message.contains("unavailable"))
        XCTAssertFalse(message.matches(regex: #"(?i)steps:\s*[\d,]+"#))
        XCTAssertFalse(message.contains("9,120"))
    }

    func testExecutorStatusUsesLoggedMealsWithoutBackend() async throws {
        try harness.seedProfile()
        _ = try harness.base.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Greek yogurt", calories: 180, protein: 17),
            date: harness.today
        )

        let response = await executor.execute(
            ParsedCommand(intent: .status, originalText: "how am I doing today?")
        )

        XCTAssertTrue(response.contains("180 /"))
        XCTAssertTrue(response.contains("Greek yogurt"))
        XCTAssertTrue(response.contains("Next:"))
    }

    // MARK: Workout advice includes workout when present

    func testWorkoutAdviceIncludesWorkoutWhenPresentInHealthContext() {
        let health = CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligenceSnapshot(
                date: Date(),
                recovery: RecoverySummary(
                    score: 74,
                    status: .moderate,
                    title: "Moderate recovery",
                    explanation: "Recovery is acceptable.",
                    recommendedTraining: "Train as planned.",
                    recommendedNutrition: "Prioritize protein.",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: []
                ),
                workout: WorkoutSummary(
                    hasWorkout: true,
                    primaryWorkoutType: .strength,
                    title: "Strength training",
                    workoutCount: 1,
                    totalDurationMinutes: 50,
                    totalActiveCalories: 320,
                    intensity: .moderate,
                    demand: .high,
                    latestWorkoutStart: Date(),
                    latestWorkoutEnd: Date(),
                    nutritionAdvice: "Refuel with protein.",
                    hydrationAdviceMl: 500,
                    explanation: "Workout logged.",
                    confidence: .high,
                    sourceSummary: "Synced workout."
                ),
                activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 45),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.8, label: "High"),
                nextBestAction: .none
            )
        )

        let message = CoachResponseBuilder.workoutAdviceResponse(
            hasWorkoutToday: true,
            healthIntelligence: health,
            assistantMessage: nil,
            contextHints: nil
        )

        XCTAssertTrue(message.contains("workout"))
        XCTAssertTrue(message.lowercased().contains("recovery") || message.lowercased().contains("protein"))
    }

    func testAICommandActionDecodesLinkedEntryIdFromSelectorUUID() throws {
        let entryId = UUID()
        let json = """
        {
          "type": "deleteEntry",
          "foodDraft": null,
          "waterDraft": null,
          "weightDraft": null,
          "workoutDraft": null,
          "startNewDayWeightKg": null,
          "adviceQuestion": null,
          "targetEntrySelector": "\(entryId.uuidString)"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let action = try JSONDecoder().decode(AICommandAction.self, from: data)
        XCTAssertEqual(action.linkedEntryId, entryId)
    }

    func testAIResponseValidatorStillAcceptsUnchangedParsedCommandShape() {
        let command = AIParsedCommand(
            originalText: "log 200g chicken",
            intent: .logFood,
            actions: [
                AICommandAction(
                    type: .logFood,
                    foodDraft: FoodDraft(
                        mealType: .lunch,
                        name: "chicken",
                        quantity: 200,
                        unit: "g",
                        calories: 330,
                        protein: 62,
                        carbs: 0,
                        fat: 7,
                        fiber: nil,
                        sodium: nil,
                        source: .manual,
                        confidence: .medium,
                        imageUrl: nil,
                        notes: nil
                    )
                )
            ],
            confidence: .medium,
            requiresConfirmation: true
        )

        if case .invalid = AIResponseValidator.validate(command) {
            XCTFail("Expected validator to accept unchanged parsed command shape")
        }
    }
}

// MARK: - Capturing recorder (minimal)

@MainActor
private final class MutationTimelineCapturingRecorder: CoachTimelineRecording, @unchecked Sendable {

    struct FoodDeletedCall {
        let entry: FoodEntry
        let supersedesEventId: UUID?
    }

    var foodDeletedCalls: [FoodDeletedCall] = []

    func recordUserMessage(text: String, messageId: UUID?, hasPhotoAttachment: Bool, occurredAt: Date?) {}
    func recordAssistantMessage(text: String, messageId: UUID?, sourceAttribution: CoachTimelineEventSourceAttribution, occurredAt: Date?) {}
    func recordFoodEstimateCreated(payload: FoodEstimatePayload, source: CoachTimelineEventSource, sourceAttribution: CoachTimelineEventSourceAttribution, confidence: CoachTimelineEventConfidence?, status: CoachTimelineEventStatus, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordFoodLogged(entry: FoodEntry, sourceAttribution: CoachTimelineEventSourceAttribution, userEditedBeforeConfirm: Bool, linkedPhotoSessionId: UUID?, occurredAt: Date?) {}
    func recordFoodRejected(payload: FoodEstimatePayload, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordFoodEdited(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {}

    func recordFoodDeleted(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {
        foodDeletedCalls.append(FoodDeletedCall(entry: entry, supersedesEventId: supersedesEventId))
    }

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
    func recordContextGenerated(payload: ContextGenerationPayload, occurredAt: Date?) {}
}

private extension String {
    func matches(regex pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}
