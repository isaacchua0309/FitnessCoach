//
//  CoachTimelineRegressionTests.swift
//  Fitness CoachTests
//
//  Regression coverage ensuring Coach Timeline Context v2 does not break core flows.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTimelineRegressionTests: XCTestCase {

    // MARK: - Food confirmation still required

    func testFoodEstimateStillRequiresConfirmation() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let timelineStore = FakeCoachTimelineStore()
        let model = harness.makeCoach(
            aiService: RegressionTimelineFoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")

        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)

        let pendingEvent = timelineStore.events.first { $0.type == .pendingConfirmationCreated }
        XCTAssertNotNil(pendingEvent)
        XCTAssertEqual(pendingEvent?.status, .pending)
    }

    // MARK: - Water log still works

    func testWaterLogStillWorksWithTimeline() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let timelineStore = FakeCoachTimelineStore()
        let model = harness.makeCoach(
            aiService: UnreachableTimelineAIService(),
            timelineStore: timelineStore
        )

        await model.send("add 500ml water")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 500)
        XCTAssertTrue(
            model.messages.last?.text.contains("500") == true
                || model.messages.last?.text.contains("water") == true
        )
    }

    // MARK: - Weight log still works

    func testWeightLogStillWorksWithTimeline() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let timelineStore = FakeCoachTimelineStore()
        let model = harness.makeCoach(
            aiService: UnreachableTimelineAIService(),
            timelineStore: timelineStore
        )

        await model.send("weight 72.5")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(try harness.dailyLogService.getTodayLog().weightKg ?? 0, 72.5, accuracy: 0.01)
        XCTAssertTrue(model.messages.last?.text.contains("72.50") == true)
    }

    // MARK: - Daily summary still works

    func testDailyReviewStillWorksWithTimeline() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 140, protein: 12),
            date: harness.today
        )

        let timelineStore = FakeCoachTimelineStore()
        let model = harness.makeCoach(
            aiService: UnreachableTimelineAIService(),
            timelineStore: timelineStore
        )

        await model.send("daily review")

        XCTAssertGreaterThanOrEqual(model.messageCount, 2)
        XCTAssertFalse(model.messages.last?.text.isEmpty == true)
    }

    // MARK: - Backend unavailable still friendly

    func testBackendUnavailableStillShowsFriendlyMessage() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let timelineStore = FakeCoachTimelineStore()
        let model = harness.makeCoach(
            aiService: FailingEstimateTimelineAIService(),
            timelineStore: timelineStore
        )

        await model.send("log mystery quinoa bowl")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.last?.text, FormaProductCopy.Error.coachUnavailable)

        let errorEvent = timelineStore.events.first { $0.type == .backendError }
        XCTAssertNotNil(errorEvent)
    }

    // MARK: - Empty timeline does not crash context build

    func testEmptyTimelineDoesNotCrashContextBuild() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let timelineStore = FakeCoachTimelineStore()
        let model = harness.makeCoach(
            aiService: LocalGreetingTimelineAIService(),
            timelineStore: timelineStore
        )

        XCTAssertTrue(timelineStore.events.isEmpty)

        await model.send("hello")

        XCTAssertGreaterThanOrEqual(model.messageCount, 2)
        XCTAssertTrue(timelineStore.events.contains { $0.type == .userMessage })
        XCTAssertTrue(timelineStore.events.contains { $0.type == .assistantMessage })
    }
}

// MARK: - Test doubles

@MainActor
private final class RegressionTimelineFoodEstimateAIService: AIServiceProtocol, @unchecked Sendable {

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

    func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
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
private final class UnreachableTimelineAIService: AIServiceProtocol, @unchecked Sendable {

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

    func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
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
private final class FailingEstimateTimelineAIService: AIServiceProtocol, @unchecked Sendable {

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

    func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
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
private final class LocalGreetingTimelineAIService: AIServiceProtocol, @unchecked Sendable {

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

    func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
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
