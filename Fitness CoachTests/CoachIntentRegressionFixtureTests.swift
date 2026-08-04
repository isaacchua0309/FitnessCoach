//
//  CoachIntentRegressionFixtureTests.swift
//  Fitness CoachTests
//
//  Loads Docs/Coach/Fixtures/coach_intent_regression_cases.json and asserts
//  deterministic phrase-guard, sanitizer, local routing, and stubbed classifier paths.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachIntentRegressionFixtureTests: XCTestCase {

    private var document: CoachIntentRegressionFixtureDocument!

    override func setUpWithError() throws {
        document = try CoachIntentRegressionFixtureLoader.load()
    }

    // MARK: - Fixture integrity

    func testFixtureMeetsMinimumCaseCount() {
        XCTAssertGreaterThanOrEqual(document.caseCount, document.minimumCaseCount)
        XCTAssertGreaterThanOrEqual(document.cases.count, 80)
    }

    func testFixtureIncludesRequiredCategories() {
        let required = Set([
            "should_not_log_food",
            "should_log_food",
            "nutrition_lookup",
            "meal_decision",
            "daily_summary",
            "edit_delete_reference",
            "water_logging",
            "weight_logging",
            "workout_redirect",
            "unsupported"
        ])
        XCTAssertTrue(required.isSubset(of: Set(document.categories)))
    }

    func testFixtureIncludesSingaporeAndLocalFoodExamples() {
        let joined = document.cases.map(\.input).joined(separator: " ").lowercased()
        let requiredFoods = [
            "chicken rice", "nasi lemak", "cai fan", "mala", "fish soup", "ban mian",
            "yong tau foo", "prata", "kaya toast", "kopi", "bubble tea", "sushi",
            "ramen", "mcspicy", "subway", "protein shake"
        ]
        for food in requiredFoods {
            XCTAssertTrue(joined.contains(food), "Missing fixture food example: \(food)")
        }
    }

    func testFixtureCaseIDsAreUnique() {
        let ids = document.cases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // MARK: - Phrase guard

    func testPhraseGuardRegressionCases() throws {
        let cases = document.cases.filter { $0.verificationLayers.contains("phrase_guard") }
        XCTAssertGreaterThanOrEqual(cases.count, 40)

        for fixtureCase in cases {
            let expected = try XCTUnwrap(
                CoachIntentRegressionFixtureMapping.coachIntent(from: fixtureCase.expectedIntent),
                "Unknown expectedIntent \(fixtureCase.expectedIntent) in \(fixtureCase.id)"
            )
            let misclassifiedRaw = CoachIntentRegressionFixtureMapping.misclassifiedRawIntent(for: fixtureCase)
            guard misclassifiedRaw == CoachIntent.logFood.rawValue else { continue }

            let raw = CoachIntentRegressionFixtureMapping.stubResult(
                for: fixtureCase,
                intent: .logFood
            )
            let corrected = CoachIntentPhraseGuard.applyGuards(to: raw, text: fixtureCase.input)

            if fixtureCase.category == "should_log_food" {
                XCTAssertEqual(
                    corrected.intent,
                    .logFood,
                    "Expected log_food preserved for \(fixtureCase.id)"
                )
                XCTAssertEqual(
                    corrected.requiresAppMutation,
                    fixtureCase.shouldCreateMutation,
                    fixtureCase.id
                )
            } else {
                XCTAssertNotEqual(
                    corrected.intent,
                    .logFood,
                    "Expected log_food correction for \(fixtureCase.id): \(fixtureCase.input)"
                )
                XCTAssertEqual(corrected.intent, expected, fixtureCase.id)
                XCTAssertFalse(corrected.requiresAppMutation, fixtureCase.id)
                XCTAssertNil(corrected.action, fixtureCase.id)
            }
        }
    }

    // MARK: - Confidence gate

    func testConfidenceGateRegressionCases() throws {
        let cases = document.cases.filter { $0.verificationLayers.contains("confidence_gate") }
        XCTAssertFalse(cases.isEmpty)

        for fixtureCase in cases {
            guard fixtureCase.category == "should_not_log_food" else { continue }
            let raw = CoachIntentRegressionFixtureMapping.stubResult(for: fixtureCase, intent: .logFood)
            let guarded = CoachIntentPhraseGuard.applyGuards(to: raw, text: fixtureCase.input)
            let decision = CoachIntentConfidenceGate.evaluate(
                guarded,
                originalText: fixtureCase.input
            )

            if case .proceed(let result) = decision {
                XCTAssertNotEqual(result.intent, .logFood, fixtureCase.id)
                XCTAssertFalse(
                    fixtureCase.forbiddenRouteHandlers?.contains("confidence_clarify") == true,
                    fixtureCase.id
                )
            } else {
                XCTFail("Expected phrase guard to allow proceed for \(fixtureCase.id)")
            }
        }

        let thresholdCase = CoachIntentResult(
            intent: .logFood,
            confidence: 0.80,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )
        if case .clarify = CoachIntentConfidenceGate.evaluate(
            thresholdCase,
            originalText: "log dinner tonight?"
        ) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected elevated threshold clarify for ambiguous question-form log_food")
        }
    }

    // MARK: - Local guard

    func testLocalGuardRegressionCases() async throws {
        let cases = document.cases.filter { $0.verificationLayers.contains("local_guard") }
        XCTAssertGreaterThanOrEqual(cases.count, 20)

        for fixtureCase in cases {
            let service = RecordingRegressionAIService()
            let decision = try await CoachRouteDecider().decide(
                text: fixtureCase.input,
                context: .regressionFixture,
                aiService: service,
                config: .default
            )

            XCTAssertEqual(
                service.classifyCoachIntentCallCount,
                0,
                "Classifier should not run for local case \(fixtureCase.id)"
            )
            XCTAssertEqual(decision.routeSource, .localGuard, fixtureCase.id)
            if let expectedHandler = fixtureCase.expectedRouteHandler {
                XCTAssertEqual(decision.chosenHandler, expectedHandler, fixtureCase.id)
            }
            if fixtureCase.category == "water_logging" || fixtureCase.category == "weight_logging" {
                XCTAssertFalse(decision.requiresAPI, fixtureCase.id)
            }
        }
    }

    // MARK: - Routing stub

    func testRoutingStubRegressionCases() async throws {
        let cases = document.cases.filter { $0.verificationLayers.contains("routing_stub") }
        XCTAssertGreaterThanOrEqual(cases.count, 30)

        for fixtureCase in cases {
            let expectedIntent = try XCTUnwrap(
                CoachIntentRegressionFixtureMapping.coachIntent(from: fixtureCase.expectedIntent),
                fixtureCase.id
            )
            let stubIntentRaw = CoachIntentRegressionFixtureMapping.misclassifiedRawIntent(for: fixtureCase)
            let stubIntent = try XCTUnwrap(
                CoachIntentRegressionFixtureMapping.coachIntent(from: stubIntentRaw),
                fixtureCase.id
            )

            let service = StubRegressionClassifierAIService(
                classifyResult: CoachIntentRegressionFixtureMapping.stubResult(
                    for: fixtureCase,
                    intent: stubIntent
                )
            )
            let decision = try await CoachRouteDecider().decide(
                text: fixtureCase.input,
                context: .regressionFixture,
                aiService: service,
                config: .default
            )

            XCTAssertEqual(service.classifyCoachIntentCallCount, 1, fixtureCase.id)
            XCTAssertEqual(decision.intent, expectedIntent, "\(fixtureCase.id): \(fixtureCase.input)")

            if let expectedHandler = fixtureCase.expectedRouteHandler {
                XCTAssertEqual(decision.chosenHandler, expectedHandler, fixtureCase.id)
            }

            if let forbidden = fixtureCase.forbiddenRouteHandlers {
                XCTAssertFalse(
                    forbidden.contains(decision.chosenHandler),
                    "\(fixtureCase.id) routed to forbidden handler \(decision.chosenHandler)"
                )
            }

            if !fixtureCase.shouldCreateMutation {
                XCTAssertNotEqual(decision.chosenHandler, "ai_estimate_food", fixtureCase.id)
                XCTAssertNotEqual(decision.chosenHandler, "local_food_estimate", fixtureCase.id)
            }
        }
    }

    // MARK: - Confirmation expectations (deterministic)

    func testConfirmationExpectationsForCatalogFoodCase() throws {
        guard let catalogCase = document.cases.first(where: { $0.id == "should_log_chicken_breast_catalog" }) else {
            XCTFail("Missing catalog food fixture case")
            return
        }
        XCTAssertTrue(catalogCase.shouldRequireConfirmation)
    }
}

// MARK: - Test doubles

private final class RecordingRegressionAIService: AIServiceProtocol, @unchecked Sendable {
    var classifyCoachIntentCallCount = 0

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        classifyCoachIntentCallCount += 1
        return CoachIntentResult(
            intent: .generalConversation,
            confidence: 0.2,
            domain: .general,
            requiresAppMutation: false,
            requiresUserContext: false,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
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
        AICoachResponse(message: "Within target.", confidence: .medium)
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
        AICoachResponse(message: "Within target.", confidence: .medium)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: CoachContextPacketV2
    ) async throws -> DailyReviewAIResponse {
        DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private final class StubRegressionClassifierAIService: AIServiceProtocol, @unchecked Sendable {
    let classifyResult: CoachIntentResult

    init(classifyResult: CoachIntentResult) {
        self.classifyResult = classifyResult
    }

    var classifyCoachIntentCallCount = 0

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        classifyCoachIntentCallCount += 1
        return classifyResult
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
        AICoachResponse(message: "Within target.", confidence: .medium)
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
        AICoachResponse(message: "Within target.", confidence: .medium)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: CoachContextPacketV2
    ) async throws -> DailyReviewAIResponse {
        DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private extension CoachContextPacketV2 {
    static var regressionFixture: CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: CoachContextMeta(
                generatedAt: Date(timeIntervalSince1970: 0),
                timezoneIdentifier: "UTC",
                localDate: "1970-01-01",
                localTime: "00:00"
            ),
            today: CoachContextTodayPacket(
                targets: CoachTodayTargetsContext(
                    calorieTarget: 2_100,
                    proteinTarget: 160,
                    carbsTarget: 220,
                    fatTarget: 65,
                    waterTargetMl: 2_500
                ),
                nutrition: CoachTodayNutritionContext(
                    caloriesConsumed: 1_200,
                    caloriesRemaining: 900,
                    proteinConsumed: 80,
                    proteinRemaining: 80,
                    carbsConsumed: 100,
                    carbsRemaining: 120,
                    fatConsumed: 30,
                    fatRemaining: 35
                ),
                hydration: CoachTodayHydrationContext(
                    waterConsumedMl: 1_000,
                    waterRemainingMl: 1_500
                ),
                weight: CoachTodayWeightContext(weightKg: 75),
                steps: CoachContextSourcedInt(value: 5_000, source: "healthKit")
            ),
            training: CoachTrainingContext(workoutsToday: 0)
        )
    }
}
