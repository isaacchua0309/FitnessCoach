//
//  CoachMessagePipelineTests.swift
//  Fitness CoachTests
//
//  FitPilot AI — regression coverage for the cheap-model-first Coach pipeline.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachMessagePipelineTests: XCTestCase {

    func testIntentClassificationDecoding() throws {
        let json = """
        {
          "intent": "meal_decision",
          "confidence": 0.92,
          "domain": "nutrition",
          "requiresAppMutation": false,
          "requiresUserContext": true,
          "canAnswerWithCheapModel": true,
          "requiresEscalation": false,
          "entities": {
            "food": "burger",
            "meal": "dinner"
          },
          "action": null,
          "reason": "User is asking whether a food fits dinner."
        }
        """

        let result = try JSONDecoder().decode(CoachIntentResult.self, from: Data(json.utf8))

        XCTAssertEqual(result.intent, .mealDecision)
        XCTAssertEqual(result.domain, .nutrition)
        XCTAssertEqual(result.entities.food, "burger")
        XCTAssertTrue(result.canAnswerWithCheapModel)
        XCTAssertFalse(result.requiresEscalation)
    }

    func testCheapAnswerRouteDoesNotFallbackForCalorieLookup() async throws {
        let pipeline = CoachMessagePipeline(
            aiService: StubCoachAIService(
                classification: CoachIntentResult(
                    intent: .calorieLookup,
                    confidence: 0.94,
                    domain: .nutrition,
                    requiresAppMutation: false,
                    requiresUserContext: false,
                    canAnswerWithCheapModel: true,
                    requiresEscalation: false
                )
            )
        )

        let decision = try await pipeline.process(
            "how many calories is a shake shack burger",
            context: .test
        )

        XCTAssertEqual(decision.detectedIntent, .calorieLookup)
        assertAIRoute(decision, type: .answerWithCheapModel)
        XCTAssertEqual(decision.chosenHandler, "cheap_model_answer")
    }

    func testMealDecisionAndProteinQuestionsDoNotFallback() async throws {
        let mealDecision = try await decision(
            for: "should i eat a full shake shack burger for dinner",
            classification: CoachIntentResult(
                intent: .mealDecision,
                confidence: 0.92,
                domain: .nutrition,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false
            )
        )
        assertAIRoute(mealDecision, type: .answerWithCheapModel)

        let proteinDecision = try await decision(
            for: "should i eat a protein shake with three full scoop for ON protein",
            classification: CoachIntentResult(
                intent: .nutritionAdvice,
                confidence: 0.9,
                domain: .nutrition,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false
            )
        )
        assertAIRoute(proteinDecision, type: .answerWithCheapModel)
    }

    func testEscalationRoutesToStrongModel() async throws {
        let decision = try await decision(
            for: "make me a 12 week fat loss plan with strength training and diet",
            classification: CoachIntentResult(
                intent: .weightLossAdvice,
                confidence: 0.9,
                domain: .fitness,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: false,
                requiresEscalation: true
            )
        )

        assertAIRoute(decision, type: .answerWithStrongModel)
        XCTAssertEqual(decision.chosenHandler, "strong_model_answer")
    }

    func testUnsupportedFallbackIsOnlyForUnsupportedIntent() async throws {
        let decision = try await decision(
            for: "what is the capital of japan",
            classification: CoachIntentResult(
                intent: .unrelatedOrUnsupported,
                confidence: 0.81,
                domain: .unrelated,
                requiresAppMutation: false,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                reason: "Outside Coach scope."
            )
        )

        XCTAssertEqual(decision.detectedIntent, .unrelatedOrUnsupported)
        if case .invalid = decision.route {
            XCTAssertEqual(decision.chosenHandler, "fallback")
            XCTAssertNotNil(decision.fallbackReason)
        } else {
            XCTFail("Expected unsupported fallback, got \(decision.route)")
        }
    }

    func testLocalMutationRoutingUsesClassifierAction() async throws {
        let waterAction = CoachAction.logWater(WaterDraft(amountMl: 600))
        let decision = try await decision(
            for: "add 600ml water",
            classification: CoachIntentResult(
                intent: .logWater,
                confidence: 0.96,
                domain: .hydration,
                requiresAppMutation: true,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                action: waterAction
            )
        )

        if case .action(let action, _) = decision.route {
            XCTAssertEqual(action, waterAction)
        } else {
            XCTFail("Expected classifier action route, got \(decision.route)")
        }
    }

    func testLocalMutationRegressionMessagesSaveToInMemoryStore() async throws {
        let container = try AppContainer(inMemory: true)
        try seedProfile(in: container)
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: AIService(llmClient: MockLLMClient()),
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.send("log 500g chicken breast")
        XCTAssertEqual(try container.actionCenter.getFoodEntries(for: Date()).count, 1)

        await model.send("add 600ml water")
        XCTAssertEqual(try container.dailyLogService.getTodayLog().waterConsumedMl, 600)

        await model.send("weight 89.2kg")
        XCTAssertEqual(try container.dailyLogService.getTodayLog().weightKg, 89.2)

        await model.send("ran 25 mins at 7:30 pace")
        XCTAssertEqual(try container.workoutLogService.getWorkouts(for: Date()).count, 1)
    }

    func testDailySummaryUsesLocalStatus() async throws {
        let pipeline = CoachMessagePipeline(aiService: StubCoachAIService(classification: .dailySummary))

        let decision = try await pipeline.process("how many calories do i have left", context: .test)

        XCTAssertEqual(decision.detectedIntent, .dailySummary)
        if case .localCommand(let command) = decision.route {
            XCTAssertEqual(command.intent, .status)
        } else {
            XCTFail("Expected local daily summary route, got \(decision.route)")
        }
    }

    func testOpenMealQuestionAnswersWithContext() async throws {
        let service = StubCoachAIService(
            classification: CoachIntentResult(
                intent: .mealDecision,
                confidence: 0.9,
                domain: .nutrition,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false
            )
        )
        let container = try AppContainer(inMemory: true)
        try seedProfile(in: container)
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: service,
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.send("what should i eat for dinner")

        XCTAssertEqual(service.answerTiers, [.cheap])
        XCTAssertTrue(service.answerContexts.first?.todaySummary?.caloriesRemaining != nil)
        XCTAssertFalse(model.messages.last?.text.contains(CoachResponseBuilder.unknownResponse) ?? true)
    }

    func testAIFailureShowsServiceUnavailableMessage() async throws {
        let container = try AppContainer(inMemory: true)
        try seedProfile(in: container)
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: StubCoachAIService(
                classification: .dailySummary,
                classifyError: AIServiceError.backendUnavailable
            ),
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.send("how many calories is a burger")

        XCTAssertEqual(model.messages.last?.text, "I couldn't reach the coach service. Try again in a moment.")
    }

    private func decision(
        for text: String,
        classification: CoachIntentResult
    ) async throws -> CoachRouteDecision {
        let pipeline = CoachMessagePipeline(aiService: StubCoachAIService(classification: classification))
        return try await pipeline.process(text, context: .test)
    }

    private func assertAIRoute(
        _ decision: CoachRouteDecision,
        type expectedType: AITaskType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case .ai(let task) = decision.route {
            XCTAssertEqual(task.type, expectedType, file: file, line: line)
        } else {
            XCTFail("Expected AI route, got \(decision.route)", file: file, line: line)
        }
    }

    private func seedProfile(in container: AppContainer) throws {
        let targets = UserTargets(
            calorieTarget: 2_100,
            proteinTarget: 160,
            carbTarget: 220,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.4,
            aggressiveness: .moderate
        )
        let draft = UserProfileDraft(
            name: "Test",
            age: 30,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 90,
            goalWeightKg: 82,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7_000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: targets
        )
        _ = try container.userProfileService.createProfile(draft)
        _ = try container.dailyLogService.ensureTodayLog()
    }
}

private final class StubCoachAIService: AIServiceProtocol, @unchecked Sendable {
    var classification: CoachIntentResult
    var classifyError: Error?
    var answerTiers: [CoachModelTier] = []
    var answerContexts: [AIContext] = []

    init(classification: CoachIntentResult, classifyError: Error? = nil) {
        self.classification = classification
        self.classifyError = classifyError
    }

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        if let classifyError {
            throw classifyError
        }
        return classification
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.requestFailed("Unexpected parseCommand call.")
    }

    func estimateFood(from text: String, context: AIContext) async throws -> FoodDraft {
        throw AIServiceError.requestFailed("Unexpected estimateFood call.")
    }

    func generateMealAdvice(
        request: MealAdviceAIRequest,
        context: AIContext
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub answer.", confidence: .medium)
    }

    func generateCoachAnswer(
        request: MealAdviceAIRequest,
        context: AIContext,
        config: CoachModelConfig,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        answerTiers.append(tier)
        answerContexts.append(context)
        return AICoachResponse(message: "Stub answer.", confidence: .medium)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }
}

private extension CoachIntentResult {
    static let dailySummary = CoachIntentResult(
        intent: .dailySummary,
        confidence: 0.95,
        domain: .app,
        requiresAppMutation: false,
        requiresUserContext: true,
        canAnswerWithCheapModel: false,
        requiresEscalation: false
    )
}

private extension AIContext {
    static let test = AIContext(
        date: Date(timeIntervalSince1970: 0),
        timezoneIdentifier: "UTC",
        userProfileSummary: nil,
        todaySummary: nil,
        commonFoods: [],
        recentMessages: []
    )
}
