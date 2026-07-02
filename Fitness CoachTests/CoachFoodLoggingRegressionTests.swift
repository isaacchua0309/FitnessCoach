//
//  CoachFoodLoggingRegressionTests.swift
//  Fitness CoachTests
//
//  End-to-end regression coverage for Coach food logging.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachFoodLoggingRegressionTests: XCTestCase {

    private let bowlPrompt = FoodLoggingGoldenFixtures.case1Prompt

    // MARK: - Primary bowl acceptance (items 2–10)

    func testBowlAcceptancePrimaryScenario() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let model = harness.makeCoach(aiService: makeFoodEstimateService(
            response: FoodLoggingGoldenFixtures.case1Response
        ))

        await model.send(bowlPrompt)

        guard case .food(let pendingDraft) = model.pendingConfirmation else {
            return XCTFail("Expected food pending confirmation for bowl")
        }

        let meal = pendingDraft.primaryMealDraft
        assertBowlAcceptanceTotals(meal)
        assertBowlComponents(meal)

        XCTAssertEqual(meal.displayName, "Chicken barley bowl with tiramisu")
        XCTAssertNil(meal.legacyQuantity, "Mixed bowl must not use a single meal-level amount")

        let form = FoodLogEditFormState(mealDraft: pendingDraft.primaryMealDraft)
        XCTAssertEqual(form.displayName, meal.displayName)
        XCTAssertEqual(form.totalCaloriesText, "\(meal.totalCalories)")
        XCTAssertEqual(form.totalProteinText, FoodEntryFormFormatter.formatMacro(meal.totalProtein))
        XCTAssertEqual(form.totalCarbsText, FoodEntryFormFormatter.formatMacro(meal.totalCarbs))
        XCTAssertEqual(form.totalFatText, FoodEntryFormFormatter.formatMacro(meal.totalFat))
        XCTAssertTrue(form.isMultiComponent)
        XCTAssertEqual(form.componentStates.count, 4)

        let barSummary = CoachPendingConfirmation.food(pendingDraft).summaryLine
        XCTAssertTrue(barSummary.contains("\(meal.totalCalories) kcal"))
        XCTAssertTrue(barSummary.contains(meal.displayName))

        XCTAssertNoThrow(try form.makeMealDraft(original: pendingDraft.primaryMealDraft))
        model.saveFoodEdit(form)
        await model.confirmPendingFromBar()

        let saved = try XCTUnwrap(harness.actionCenter.getFoodEntries(for: harness.today).first)
        XCTAssertEqual(saved.name, meal.displayName)
        XCTAssertEqual(saved.calories, meal.totalCalories)
        XCTAssertEqual(saved.protein, meal.totalProtein, accuracy: 0.01)
        XCTAssertEqual(saved.carbs, meal.totalCarbs, accuracy: 0.01)
        XCTAssertEqual(saved.fat, meal.totalFat, accuracy: 0.01)
        XCTAssertEqual(saved.components?.count, 4)
        XCTAssertNil(saved.quantity)
    }

    func testCollapsedBowl430IsRejected() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let model = harness.makeCoach(aiService: makeFoodEstimateService(
            response: FoodLoggingGoldenFixtures.case1CollapsedResponse
        ))

        await model.send(bowlPrompt)

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.aiNotUnderstood)
    }

    // MARK: - Single food (item 1)

    func testSingleFoodStillWorks() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let model = harness.makeCoach(aiService: makeFoodEstimateService(
            response: FoodLoggingGoldenFixtures.case4Response
        ))

        await model.send(FoodLoggingGoldenFixtures.case4Prompt)

        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Expected single-food pending confirmation")
        }

        let meal = draft.primaryMealDraft
        XCTAssertEqual(meal.components.count, 1)
        XCTAssertGreaterThanOrEqual(meal.totalCalories, 240)
        XCTAssertLessThanOrEqual(meal.totalCalories, 260)
        XCTAssertEqual(meal.legacyQuantity, 150)
        XCTAssertEqual(meal.legacyUnit, "g")

        let form = FoodLogEditFormState(mealDraft: meal)
        XCTAssertFalse(form.isMultiComponent)
        await model.confirmPendingFromBar()

        let saved = try XCTUnwrap(harness.actionCenter.getFoodEntries(for: harness.today).first)
        XCTAssertEqual(saved.calories, meal.totalCalories)
    }

    // MARK: - Pipeline regressions (items 3–7)

    func testQuantityParsingPreservesPerComponentAmounts() {
        let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1)

        XCTAssertEqual(meal.components[0].quantity, 150)
        XCTAssertEqual(meal.components[0].unit, "g")
        XCTAssertEqual(meal.components[2].quantity, 1)
        XCTAssertEqual(meal.components[2].unit, "tbsp")
        XCTAssertEqual(meal.components[3].quantity, 55)
    }

    func testCookedStateIsRespected() {
        let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1)
        XCTAssertEqual(meal.components[0].preparationState, "cooked")
        XCTAssertEqual(meal.components[1].preparationState, "cooked")

        let cookedRice = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case5)
        XCTAssertEqual(cookedRice.components.first?.preparationState, "cooked")
        XCTAssertLessThan(cookedRice.totalCalories, 400)
    }

    func testSauceAndDessertComponentsAreRetained() {
        let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1)
        XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("dressing") }))
        XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("tiramisu") }))
    }

    func testMacroCaloriesAlignWithDisplayedTotals() {
        let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1)
        let computed = meal.totalProtein * 4 + meal.totalCarbs * 4 + meal.totalFat * 9
        let delta = abs(computed - Double(meal.totalCalories)) / Double(meal.totalCalories)
        XCTAssertLessThanOrEqual(delta, 0.15)
    }

    // MARK: - Low confidence warning (item 11)

    func testLowConfidenceUnderestimatedBowlShowsWarning() {
        let underestimated = FoodLogDraft(
            displayName: "bowl with chicken breast, barley rice mix, dressing, tiramisu",
            components: [
                FoodComponent(
                    name: "cooked chicken breast",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 165,
                    protein: 31,
                    carbs: 0,
                    fat: 3.6,
                    sourceText: "150g cooked chicken breast"
                ),
                FoodComponent(
                    name: "cooked barley rice",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 130,
                    protein: 3,
                    carbs: 28,
                    fat: 1,
                    sourceText: "150g cooked barley rice"
                ),
                FoodComponent(
                    name: "creamy dressing",
                    quantity: 1,
                    unit: "tbsp",
                    calories: 35,
                    protein: 0,
                    carbs: 1,
                    fat: 1,
                    sourceText: "1 tbsp dressing"
                ),
                FoodComponent(
                    name: "tiramisu",
                    quantity: 55,
                    unit: "g",
                    calories: 100,
                    protein: 2,
                    carbs: 13,
                    fat: 3.4,
                    sourceText: "50-60g tiramisu"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )
        let sanity = NutritionSanityValidator.validate(
            meal: underestimated,
            prompt: bowlPrompt,
            confidence: .high
        )

        XCTAssertFalse(sanity.isAcceptable)
        XCTAssertEqual(sanity.confidence, .low)
        XCTAssertTrue(sanity.mealDraft.warnings.contains(NutritionSanityResult.underEstimatedUserMessage))
    }

    // MARK: - Edit safety (item 12)

    func testEditingMultiComponentMealDoesNotCrash() throws {
        var form = FoodLogEditFormState(mealDraft: FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1))
        form.totalCaloriesText = "680"
        form.totalProteinText = "53"
        form.totalCarbsText = "61"
        form.totalFatText = "23"

        XCTAssertNoThrow(try form.makeMealDraft(original: FoodLoggingGoldenFixtures.case1MealDraft))
    }

    // MARK: - Helpers

    private func assertBowlAcceptanceTotals(_ meal: FoodLogDraft) {
        XCTAssertGreaterThanOrEqual(meal.totalCalories, 650)
        XCTAssertLessThanOrEqual(meal.totalCalories, 700)
        XCTAssertNotEqual(meal.totalCalories, 430)
        XCTAssertGreaterThanOrEqual(meal.totalCalories, 550)

        XCTAssertGreaterThanOrEqual(meal.totalProtein, 48)
        XCTAssertLessThanOrEqual(meal.totalProtein, 56)

        XCTAssertGreaterThanOrEqual(meal.totalCarbs, 54)
        XCTAssertLessThanOrEqual(meal.totalCarbs, 66)

        XCTAssertGreaterThanOrEqual(meal.totalFat, 18)
        XCTAssertLessThanOrEqual(meal.totalFat, 26)
    }

    private func assertBowlComponents(_ meal: FoodLogDraft) {
        XCTAssertGreaterThanOrEqual(meal.components.count, 4)
        XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("chicken") }))
        XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("barley") || $0.name.lowercased().contains("rice") }))
        XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("dressing") }))
        XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("tiramisu") }))
    }

    private func makeFoodEstimateService(response: AIFoodEstimateResponse) -> AIServiceProtocol {
        RegressionFoodEstimateAIService(response: response)
    }
}

// MARK: - Test doubles

@MainActor
private final class RegressionFoodEstimateAIService: AIServiceProtocol, @unchecked Sendable {
    private let response: AIFoodEstimateResponse

    init(response: AIFoodEstimateResponse) {
        self.response = response
    }

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
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
        context: AIContext,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        response
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
