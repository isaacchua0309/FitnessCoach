//
//  CoachModelTimelineRecordingTests.swift
//  Fitness CoachTests
//
//  Verifies CoachModel wires CoachTimelineRecorder into the text message flow.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachModelTimelineRecordingTests: XCTestCase {

    private var timelineStore: FakeCoachTimelineStore!
    private var harness: CoachRoutingIntegrationTestSupport.Harness!

    override func setUp() async throws {
        timelineStore = FakeCoachTimelineStore()
        harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
    }

    override func tearDown() {
        timelineStore = nil
        harness = nil
        super.tearDown()
    }

    func testSendingMessageRecordsUserEvent() async throws {
        let model = harness.makeCoach(
            aiService: LocalGreetingAIService(),
            timelineStore: timelineStore
        )

        await model.send("hello")

        let userEvent = try await waitForEvent(matching: { $0.type == .userMessage })
        XCTAssertEqual(userEvent.source, .coachUI)
        XCTAssertEqual(userEvent.status, .confirmed)
        XCTAssertNotNil(userEvent.linkedMessageId)
        guard case .message(let payload) = userEvent.payload else {
            return XCTFail("Expected message payload")
        }
        XCTAssertEqual(payload.role, "user")
        XCTAssertEqual(payload.textPreview, "hello")
    }

    func testAssistantReplyRecordsAssistantEvent() async throws {
        let model = harness.makeCoach(
            aiService: LocalGreetingAIService(),
            timelineStore: timelineStore
        )

        await model.send("hello")

        let assistantEvent = try await waitForEvent(matching: { $0.type == .assistantMessage })
        XCTAssertEqual(assistantEvent.source, .aiBackend)
        XCTAssertEqual(assistantEvent.status, .confirmed)
        XCTAssertNotNil(assistantEvent.linkedMessageId)
        guard case .message(let payload) = assistantEvent.payload else {
            return XCTFail("Expected message payload")
        }
        XCTAssertEqual(payload.role, "assistant")
        XCTAssertFalse(payload.textPreview.isEmpty)
    }

    func testPendingFoodRecordsPendingConfirmationCreatedEvent() async throws {
        let model = harness.makeCoach(
            aiService: TimelineFoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")

        let pendingEvent = try await waitForEvent(matching: { $0.type == .pendingConfirmationCreated })
        XCTAssertEqual(pendingEvent.status, .pending)
        XCTAssertEqual(pendingEvent.sourceAttribution, .estimateFood)
        guard case .confirmation(let payload) = pendingEvent.payload else {
            return XCTFail("Expected confirmation payload")
        }
        XCTAssertEqual(payload.kind, "food")
        XCTAssertNotNil(payload.pendingConfirmationId)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    func testRejectingPendingFoodRecordsRejectedAndFoodRejectedEvents() async throws {
        let model = harness.makeCoach(
            aiService: TimelineFoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")
        _ = try await waitForEvent(matching: { $0.type == .pendingConfirmationCreated })

        await model.send("no")

        let rejectedEvent = try await waitForEvent(matching: { $0.type == .pendingConfirmationRejected })
        XCTAssertEqual(rejectedEvent.status, .rejected)
        XCTAssertTrue(timelineStore.events.contains(where: { $0.type == .foodRejected }))
        XCTAssertNil(model.pendingConfirmation)
    }

    func testBackendErrorRecordsBackendErrorEvent() async throws {
        let model = harness.makeCoach(
            aiService: FailingTimelineAIService(),
            timelineStore: timelineStore
        )

        await model.send("log mystery quinoa special")

        let errorEvent = try await waitForEvent(matching: { $0.type == .backendError })
        guard case .error(let payload) = errorEvent.payload else {
            return XCTFail("Expected error payload")
        }
        XCTAssertEqual(payload.category, "backend_unavailable")
        XCTAssertNotNil(payload.userMessagePreview)
    }

    func testRecorderFailureDoesNotBreakCoachSend() async throws {
        timelineStore.injectedAppendError = CoachTimelineStoreError.invalidDateRange
        let model = harness.makeCoach(
            aiService: LocalGreetingAIService(),
            timelineStore: timelineStore
        )

        await model.send("hello")

        XCTAssertGreaterThanOrEqual(model.messageCount, 2)
        XCTAssertGreaterThanOrEqual(timelineStore.appendAttempts, 1)
    }

    // MARK: Helpers

    private func waitForEvent(
        matching predicate: @escaping (CoachTimelineEvent) -> Bool,
        timeout: TimeInterval = 1.0
    ) async throws -> CoachTimelineEvent {
        try await timelineStore.waitUntil(timeout: timeout) {
            self.timelineStore.events.contains(where: predicate)
        }
        return try XCTUnwrap(timelineStore.events.first(where: predicate))
    }
}

// MARK: - Test doubles

@MainActor
private final class LocalGreetingAIService: AIServiceProtocol, @unchecked Sendable {

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        throw AIServiceError.backendUnavailable
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionEstimate(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionComparison(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionComparisonResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: CoachContextPacketV2
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

@MainActor
private final class TimelineFoodEstimateAIService: AIServiceProtocol, @unchecked Sendable {

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachIntentResult(
            intent: .logFood,
            confidence: 0.92,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: nil
        )
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        AIFoodEstimateResponse(
            foodLogDrafts: [
                FoodLogDraft(
                    displayName: "Chicken rice bowl",
                    components: [
                        FoodComponent(
                            name: "Chicken rice bowl",
                            calories: 620,
                            protein: 42,
                            carbs: 55,
                            fat: 18,
                            confidence: .medium,
                            sourceText: prompt
                        )
                    ],
                    confidence: .medium,
                    source: .aiTextEstimate
                )
            ],
            confidence: .medium,
            requiresConfirmation: true,
            assistantMessage: "Confirm before logging."
        )
    }

    func generateMealAdvice(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionEstimate(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionComparison(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionComparisonResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: CoachContextPacketV2
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

@MainActor
private final class FailingTimelineAIService: AIServiceProtocol, @unchecked Sendable {

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachIntentResult(
            intent: .logFood,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: nil
        )
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionEstimate(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionComparison(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionComparisonResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: CoachContextPacketV2
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private extension FakeCoachTimelineStore {

    func waitUntil(
        timeout: TimeInterval = 1.0,
        predicate: @escaping () -> Bool
    ) async throws {
        let satisfied = await AsyncTestSupport.waitUntil(
            maxYields: Int(timeout * 100),
            predicate: predicate
        )
        if !satisfied {
            throw NSError(domain: "CoachModelTimelineRecordingTests", code: 1)
        }
    }
}
