//
//  CoachRoutingTests.swift
//  Fitness CoachTests
//
//  FitPilot AI — regression coverage for local-first Coach routing.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachRoutingTests: XCTestCase {

    private var decider = CoachRouteDecider()

    // MARK: - Local guard (no classify call)

    func testGreetingRoutesLocally() async throws {
        try await assertLocalGuard("hi", expectedHandler: "greeting")
        try await assertLocalGuard("hello", expectedHandler: "greeting")
        try await assertLocalGuard("thanks", expectedHandler: "greeting")
    }

    func testNoOpRoutesLocally() async throws {
        try await assertLocalGuard("", expectedHandler: "no_op")
        try await assertLocalGuard("???", expectedHandler: "no_op")
    }

    func testDeterministicCommandsRouteLocally() async throws {
        try await assertLocalGuard("add 500ml water", expectedHandler: "local_command")
        try await assertLocalGuard("drank 1.5L water", expectedHandler: "local_command")
        try await assertLocalGuard("weight 90.15", expectedHandler: "local_command")
        try await assertLocalGuard("status", expectedHandler: "local_command")
        try await assertLocalGuard("daily review", expectedHandler: "local_command")
        try await assertLocalGuard("undo water", expectedHandler: "local_command")
    }

    func testExplicitMacroFoodRoutesLocally() async throws {
        try await assertLocalGuard(
            "log chicken 400 calories 50 protein 0 carbs 5 fat",
            expectedHandler: "local_command"
        )
    }

    func testCommonFoodEstimateRoutesLocally() async throws {
        try await assertLocalGuard("log 500g chicken breast", expectedHandler: "local_food_estimate")
    }

    func testMediumConfidenceFoodUsesClassifier() async throws {
        try await assertClassifierRoute(
            "log 3 scoops whey",
            stub: stubIntent(.logFood),
            expectedHandler: "ai_estimate_food",
            expectedTier: .cheap
        )
    }

    func testCaloriesLeftStaysLocal() async throws {
        try await assertLocalGuard("how many calories left", expectedHandler: "local_command")
    }

    // MARK: - Cheap classifier routing

    func testVagueFoodRoutesToEstimateFood() async throws {
        try await assertClassifierRoute(
            "log chicken rice",
            stub: stubIntent(.logFood),
            expectedHandler: "ai_estimate_food",
            expectedTier: .cheap
        )
    }

    func testMealAdviceRoutesToCheapTier() async throws {
        try await assertClassifierRoute(
            "should I eat a kebab tonight?",
            stub: stubIntent(.mealDecision),
            expectedHandler: "cheap_meal_advice",
            expectedTier: .cheap
        )
    }

    func testCalorieLookupRoutesToCheapMealAdvice() async throws {
        try await assertClassifierRoute(
            "how many calories does a double mcspicy have",
            stub: stubIntent(.calorieLookup),
            expectedHandler: "cheap_meal_advice",
            expectedTier: .cheap
        )
    }

    func testWorkoutRoutesToParseWorkout() async throws {
        try await assertClassifierRoute(
            "bench 5x5 90kg",
            stub: stubIntent(.logWorkout),
            expectedHandler: "ai_parse_workout",
            expectedTier: .cheap
        )
    }

    func testDeleteRoutesToParseEditDelete() async throws {
        try await assertClassifierRoute(
            "delete lunch",
            stub: stubIntent(.deleteLog),
            expectedHandler: "ai_delete_entry",
            expectedTier: .cheap
        )
    }

    func testEscalatedAdviceUsesStrongTier() async throws {
        try await assertClassifierRoute(
            "help me plan a 12 week cut",
            stub: stubIntent(.weightLossAdvice, requiresEscalation: true),
            expectedHandler: "strong_meal_advice",
            expectedTier: .strong
        )
    }

    func testFollowUpUsesClassifierNotKeywords() async throws {
        let service = StubClassifierAIService(classifyResult: stubIntent(.mealDecision))
        let localDecider = CoachRouteDecider()
        var context = AIContext.test
        context.recentMessages = [
            AIMessageContext(role: .user, text: "should I eat a burger tonight"),
            AIMessageContext(role: .assistant, text: "You have 685 kcal remaining.")
        ]

        let decision = try await localDecider.decide(
            text: "how about a double mcspicy",
            context: context,
            aiService: service,
            config: .default
        )

        XCTAssertEqual(service.classifyCoachIntentCallCount, 1)
        XCTAssertEqual(decision.routeSource, .cheapClassifier)
        XCTAssertTrue(decision.requiresAPI)
        if case .ai(let task) = decision.route {
            XCTAssertEqual(task.tier, .cheap)
        } else {
            XCTFail("Expected AI route, got \(decision.route)")
        }
    }

    // MARK: - Confirmation policy

    func testHighConfidenceLocalFoodExecutesImmediately() {
        let estimate = LocalFoodEstimate(
            draft: FoodDraft(
                mealType: nil,
                name: "Chicken breast",
                quantity: 500,
                unit: "g",
                calories: 825,
                protein: 155,
                carbs: 0,
                fat: 18,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil
            ),
            confidence: .high,
            requiresConfirmation: false,
            explanation: "Local table"
        )
        let request = LocalFoodEstimateRequest(
            estimate: estimate,
            originalText: "log 500g chicken breast",
            userAskedToLog: true
        )
        XCTAssertEqual(ConfirmationPolicy.decision(for: request), .executeImmediately)
    }

    func testMediumConfidenceLocalFoodRequiresConfirmation() {
        let estimate = LocalFoodEstimate(
            draft: FoodDraft(
                mealType: nil,
                name: "Cooked rice",
                quantity: 1,
                unit: "cup",
                calories: 205,
                protein: 4,
                carbs: 45,
                fat: 0,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .medium,
                imageUrl: nil,
                notes: nil
            ),
            confidence: .medium,
            requiresConfirmation: true,
            explanation: "Local table"
        )
        let request = LocalFoodEstimateRequest(
            estimate: estimate,
            originalText: "log 1 cup rice",
            userAskedToLog: true
        )
        if case .requiresConfirmation = ConfirmationPolicy.decision(for: request) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected confirmation")
        }
    }

    func testWorkoutRequiresConfirmationBeforeLogging() {
        let draft = WorkoutDraft(
            name: "Run",
            durationMinutes: 31,
            estimatedCaloriesBurned: 300,
            intensity: .moderate,
            recoveryDemand: .moderate,
            notes: nil,
            exerciseSets: []
        )
        if case .requiresConfirmation = ConfirmationPolicy.decision(forWorkout: draft) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Workout should require confirmation")
        }
    }

    // MARK: - Integration

    func testLocalRegressionMessagesSaveToInMemoryStore() async throws {
        let container = try AppContainer(inMemory: true)
        try seedProfile(in: container)
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: RecordingAIService(),
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.send("log 500g chicken breast")
        XCTAssertEqual(try container.actionCenter.getFoodEntries(for: Date()).count, 1)

        await model.send("add 600ml water")
        XCTAssertEqual(try container.dailyLogService.getTodayLog().waterConsumedMl, 600)

        await model.send("weight 89.2kg")
        XCTAssertEqual(try container.dailyLogService.getTodayLog().weightKg, 89.2)
    }

    func testAIFailureShowsGracefulMessage() async throws {
        let container = try AppContainer(inMemory: true)
        try seedProfile(in: container)
        let service = StubClassifierAIService(
            classifyResult: stubIntent(.mealDecision),
            mealAdviceError: AIServiceError.backendUnavailable
        )
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: service,
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.send("should I eat a kebab tonight?")
        XCTAssertEqual(
            model.messages.last?.text,
            FormaProductCopy.Error.coachUnavailable
        )
        XCTAssertEqual(service.classifyCoachIntentCallCount, 1)
        XCTAssertEqual(service.estimateFoodCallCount, 0)
        XCTAssertEqual(service.mealAdviceCallCount, 1)
    }

    func testAuthenticationFailureSetsInlineRetryStateNotChatBubble() async throws {
        let container = try AppContainer(inMemory: true)
        try seedProfile(in: container)
        let service = StubClassifierAIService(
            classifyResult: stubIntent(.mealDecision),
            mealAdviceError: AIServiceError.authenticationFailed
        )
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: service,
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.send("should I eat a kebab tonight?")

        XCTAssertTrue(model.showsAuthRetry)
        XCTAssertEqual(model.errorTitle, AIServiceError.coachSessionFailureTitle)
        XCTAssertEqual(model.errorMessage, AIServiceError.coachSessionFailureMessage)
        XCTAssertEqual(model.messages.count, 1)
        XCTAssertEqual(model.messages.last?.role, .user)
        XCTAssertEqual(service.classifyCoachIntentCallCount, 1)
        XCTAssertEqual(service.mealAdviceCallCount, 1)
    }

    // MARK: - Helpers

    private func assertLocalGuard(
        _ text: String,
        expectedHandler: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let service = RecordingAIService()
        let localDecider = CoachRouteDecider()
        let decision = try await localDecider.decide(
            text: text,
            context: .test,
            aiService: service,
            config: .default
        )

        XCTAssertEqual(service.classifyCoachIntentCallCount, 0, file: file, line: line)
        XCTAssertFalse(decision.requiresAPI, file: file, line: line)
        XCTAssertEqual(decision.routeSource, .localGuard, file: file, line: line)
        XCTAssertEqual(decision.chosenHandler, expectedHandler, file: file, line: line)
        if case .ai = decision.route {
            XCTFail("Expected local route for '\(text)'", file: file, line: line)
        }
    }

    private func assertClassifierRoute(
        _ text: String,
        stub: CoachIntentResult,
        expectedHandler: String,
        expectedTier: CoachModelTier,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let service = StubClassifierAIService(classifyResult: stub)
        let localDecider = CoachRouteDecider()
        let decision = try await localDecider.decide(
            text: text,
            context: .test,
            aiService: service,
            config: .default
        )

        XCTAssertEqual(service.classifyCoachIntentCallCount, 1, file: file, line: line)
        XCTAssertTrue(decision.requiresAPI, file: file, line: line)
        XCTAssertEqual(decision.routeSource, .cheapClassifier, file: file, line: line)
        XCTAssertEqual(decision.intent, stub.intent, file: file, line: line)
        XCTAssertEqual(decision.modelTier, expectedTier, file: file, line: line)
        XCTAssertEqual(decision.chosenHandler, expectedHandler, file: file, line: line)
        if case .ai = decision.route {
            XCTAssertTrue(true, file: file, line: line)
        } else if case .classifiedFood = decision.route, expectedHandler == "classified_food" {
            XCTAssertTrue(true, file: file, line: line)
        } else {
            XCTFail("Expected AI route for '\(text)', got \(decision.route)", file: file, line: line)
        }
    }

    private func stubIntent(
        _ intent: CoachIntent,
        canAnswerWithCheapModel: Bool = true,
        requiresEscalation: Bool = false,
        action: CoachAction? = nil
    ) -> CoachIntentResult {
        CoachIntentResult(
            intent: intent,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: intent == .logFood || intent == .logWorkout,
            requiresUserContext: true,
            canAnswerWithCheapModel: canAnswerWithCheapModel,
            requiresEscalation: requiresEscalation,
            action: action
        )
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

// MARK: - Test doubles

private final class RecordingAIService: AIServiceProtocol, @unchecked Sendable {
    var classifyCoachIntentCallCount = 0
    var estimateFoodCallCount = 0
    var mealAdviceCallCount = 0
    var parseWorkoutCallCount = 0
    var mealAdviceError: Error?

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        classifyCoachIntentCallCount += 1
        return CoachIntentResult(
            intent: .unrelatedOrUnsupported,
            confidence: 0,
            domain: .unrelated,
            requiresAppMutation: false,
            requiresUserContext: false,
            canAnswerWithCheapModel: false,
            requiresEscalation: false
        )
    }

    func estimateFood(prompt: String, context: AIContext) async throws -> AIFoodEstimateResponse {
        estimateFoodCallCount += 1
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        mealAdviceCallCount += 1
        if let mealAdviceError { throw mealAdviceError }
        return AICoachResponse(message: "Stub advice.", confidence: .medium)
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        parseWorkoutCallCount += 1
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private final class StubClassifierAIService: AIServiceProtocol, @unchecked Sendable {
    var classifyCoachIntentCallCount = 0
    var estimateFoodCallCount = 0
    var mealAdviceCallCount = 0
    var parseWorkoutCallCount = 0

    let classifyResult: CoachIntentResult
    var mealAdviceError: Error?

    init(classifyResult: CoachIntentResult, mealAdviceError: Error? = nil) {
        self.classifyResult = classifyResult
        self.mealAdviceError = mealAdviceError
    }

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        classifyCoachIntentCallCount += 1
        return classifyResult
    }

    func estimateFood(prompt: String, context: AIContext) async throws -> AIFoodEstimateResponse {
        estimateFoodCallCount += 1
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        mealAdviceCallCount += 1
        if let mealAdviceError { throw mealAdviceError }
        return AICoachResponse(message: "Stub advice.", confidence: .medium)
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        parseWorkoutCallCount += 1
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private extension AIContext {
    static var test: AIContext {
        AIContext(
            date: Date(timeIntervalSince1970: 0),
            timezoneIdentifier: "UTC",
            userProfileSummary: nil,
            todaySummary: TodayAISummary(
                calorieTarget: 2_100,
                caloriesConsumed: 1_200,
                caloriesRemaining: 900,
                proteinTarget: 160,
                proteinConsumed: 80,
                proteinRemaining: 80,
                carbsTarget: 220,
                carbsConsumed: 100,
                carbsRemaining: 120,
                fatTarget: 65,
                fatConsumed: 30,
                fatRemaining: 35,
                waterTargetMl: 2_500,
                waterConsumedMl: 1_000,
                waterRemainingMl: 1_500,
                weightKg: 90,
                steps: 5_000,
                workoutCaloriesBurned: 0,
                workoutsToday: 0,
                recentMeals: []
            ),
            commonFoods: [],
            recentMessages: []
        )
    }
}
