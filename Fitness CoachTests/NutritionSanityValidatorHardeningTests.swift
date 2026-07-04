//
//  NutritionSanityValidatorHardeningTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NutritionSanityValidatorHardeningTests: XCTestCase {

    // MARK: - Macro mismatch

    func testSmallMacroMismatchIsRepairedSafely() {
        let meal = FoodLogDraft(
            displayName: "Greek yogurt",
            components: [
                FoodComponent(
                    name: "greek yogurt",
                    quantity: 170,
                    unit: "g",
                    calories: 100,
                    protein: 15,
                    carbs: 6,
                    fat: 0.5
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 170g greek yogurt",
            confidence: .high
        )

        XCTAssertTrue(result.repairedMacros)
        XCTAssertTrue(result.isAcceptable)
        XCTAssertEqual(result.mealDraft.components[0].calories, 89)
    }

    func testLargeMacroMismatchDowngradesConfidence() {
        let meal = FoodLogDraft(
            displayName: "Eggs",
            components: [
                FoodComponent(
                    name: "eggs",
                    quantity: 2,
                    unit: "count",
                    calories: 300,
                    protein: 10,
                    carbs: 2,
                    fat: 5
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 2 eggs",
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.mealDraft.uncertaintyReasons.isEmpty == false || result.issues.isEmpty == false)
    }

    func testMacroMismatchAddsUncertaintyWhenRepairedWithVisibleDelta() {
        let meal = FoodLogDraft(
            displayName: "Banana",
            components: [
                FoodComponent(
                    name: "banana",
                    calories: 120,
                    protein: 1,
                    carbs: 26,
                    fat: 0.3
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log banana",
            confidence: .medium
        )

        XCTAssertTrue(result.repairedMacros)
        XCTAssertTrue(result.mealDraft.uncertaintyReasons.contains(where: { $0.contains("Adjusted") }))
    }

    // MARK: - Sanity downgrade cases

    func testChickenRiceBelow350DowngradesWithoutSmallPortionHint() {
        let meal = underestimatedChickenRice()

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log chicken rice",
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("too low for a normal portion") }))
        XCTAssertTrue(result.mealDraft.warnings.contains(NutritionSanityResult.underEstimatedUserMessage))
    }

    func testChickenRiceSmallPortionDoesNotTriggerDishFloor() {
        let meal = underestimatedChickenRice()

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log small chicken rice",
            confidence: .high
        )

        XCTAssertFalse(
            result.issues.contains(where: { $0.contains("too low for a normal portion of this dish") })
        )
    }

    func testCharKwayTeowBelow450Downgrades() {
        let meal = FoodLogDraft(
            displayName: "char kway teow",
            components: [
                FoodComponent(
                    name: "char kway teow",
                    quantity: 1,
                    unit: "plate",
                    calories: 380,
                    protein: 12,
                    carbs: 45,
                    fat: 14,
                    sourceText: "hawker char kway teow"
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log char kway teow",
            confidence: .medium
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertEqual(result.confidence, .low)
    }

    func testMalaBelow500DowngradesUnlessLightPortion() {
        let meal = FoodLogDraft(
            displayName: "mala",
            components: [
                FoodComponent(
                    name: "mala vegetables",
                    calories: 420,
                    protein: 18,
                    carbs: 30,
                    fat: 20,
                    sourceText: "mala bowl"
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let strict = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log mala",
            confidence: .medium
        )
        XCTAssertFalse(strict.isAcceptable)

        let light = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log light mala",
            confidence: .medium
        )
        XCTAssertFalse(
            light.issues.contains(where: { $0.contains("too low for a normal portion of this dish") })
        )
    }

    func test300gChickenBreastBelowRangeDowngrades() {
        let meal = FoodLogDraft(
            displayName: "chicken breast",
            components: [
                FoodComponent(
                    name: "cooked skinless chicken breast",
                    quantity: 300,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 350,
                    protein: 55,
                    carbs: 0,
                    fat: 8,
                    sourceText: "300g cooked skinless chicken breast"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 300g cooked skinless chicken breast",
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("300g chicken breast") }))
    }

    func test500mlFullCreamMilkOutsideRangeDowngrades() {
        let meal = FoodLogDraft(
            displayName: "full cream milk",
            components: [
                FoodComponent(
                    name: "full cream milk",
                    quantity: 500,
                    unit: "ml",
                    calories: 150,
                    protein: 8,
                    carbs: 12,
                    fat: 8,
                    sourceText: "500ml full cream milk"
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 500ml full cream milk",
            confidence: .medium
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("500ml full cream milk") }))
    }

    // MARK: - Hidden oil/sauce

    func testHiddenOilSauceAddsUncertaintyAndWidensRange() {
        let meal = FoodLogDraft(
            displayName: "chicken rice",
            components: [
                FoodComponent(name: "rice", calories: 260, protein: 5, carbs: 56, fat: 1),
                FoodComponent(name: "chicken", calories: 180, protein: 35, carbs: 0, fat: 4),
            ],
            confidence: .medium,
            source: .aiTextEstimate,
            calorieRangeLower: 430,
            calorieRangeUpper: 450
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log chicken rice",
            confidence: .medium
        )

        XCTAssertTrue(
            result.mealDraft.uncertaintyReasons.contains(where: { $0.lowercased().contains("hidden oil") })
        )
        XCTAssertGreaterThanOrEqual(
            (result.mealDraft.calorieRangeUpper ?? 0) - (result.mealDraft.calorieRangeLower ?? 0),
            FoodCalorieRangePolicy.minimumWidth(calories: result.mealDraft.totalCalories, confidence: .low)
        )
    }

    func testHiddenOilSauceAddsComponentWhenCaloriesFarBelowFloor() {
        let meal = FoodLogDraft(
            displayName: "chicken rice",
            components: [
                FoodComponent(name: "chicken rice", calories: 280, protein: 20, carbs: 35, fat: 8)
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log chicken rice",
            confidence: .medium
        )

        XCTAssertTrue(
            result.mealDraft.components.contains(where: { $0.name.contains("oil/sauce") })
        )
        XCTAssertGreaterThan(result.mealDraft.totalCalories, 280)
    }

    // MARK: - Range widening

    func testLowConfidenceForcesWideCalorieRange() {
        let meal = FoodLogDraft(
            displayName: "rice bowl",
            components: [
                FoodComponent(name: "rice bowl", calories: 500, protein: 12, carbs: 80, fat: 10)
            ],
            confidence: .low,
            source: .aiTextEstimate,
            uncertaintyReasons: ["Portion size is unclear."],
            calorieRangeLower: 495,
            calorieRangeUpper: 505
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log rice bowl",
            confidence: .low
        )

        let lower = result.mealDraft.calorieRangeLower ?? 0
        let upper = result.mealDraft.calorieRangeUpper ?? 0
        XCTAssertGreaterThanOrEqual(
            upper - lower,
            FoodCalorieRangePolicy.minimumWidth(calories: 500, confidence: .low)
        )
        XCTAssertTrue(result.mealDraft.warnings.contains(NutritionSanityResult.lowConfidenceReviewUserMessage))
    }

    // MARK: - Clarification policy

    func testRequiresClarificationCapsPresentationConfidence() {
        let meal = FoodLogDraft(
            displayName: "cai fan",
            components: [
                FoodComponent(name: "rice", calories: 200, protein: 4, carbs: 44, fat: 1),
                FoodComponent(name: "stir fry", calories: 180, protein: 10, carbs: 8, fat: 12),
            ],
            confidence: .medium,
            source: .aiTextEstimate,
            requiresClarificationBeforeLogging: true,
            suggestedClarifications: ["Which dishes did you pick?"]
        )

        let presentation = ConfirmationPolicy.presentationConfidence(for: meal)
        XCTAssertEqual(presentation, .low)
    }

    func testSanityFlagsClarificationForLowConfidenceEstimate() {
        let meal = FoodLogDraft(
            displayName: "hawker plate",
            components: [
                FoodComponent(name: "mixed plate", calories: 500, protein: 20, carbs: 55, fat: 18)
            ],
            confidence: .low,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log hawker plate",
            confidence: .low
        )

        XCTAssertTrue(result.mealDraft.requiresClarificationBeforeLogging)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertFalse(result.mealDraft.suggestedClarifications.isEmpty)
    }

    // MARK: - Exact grams preserved

    func testExactUserProvidedGramsAreNotChangedDuringMacroRepair() {
        var meal = FoodLogDraft(
            displayName: "chicken breast",
            components: [
                FoodComponent(
                    name: "cooked skinless chicken breast",
                    quantity: 300,
                    unit: "g",
                    calories: 470,
                    protein: 90,
                    carbs: 0,
                    fat: 10,
                    sourceText: "300g cooked skinless chicken breast"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 300g cooked skinless chicken breast",
            confidence: .high
        )

        XCTAssertEqual(result.mealDraft.components[0].quantity, 300)
        XCTAssertEqual(result.mealDraft.components[0].unit, "g")
    }

    func testExactUserProvidedGramsSkipUnsafeMacroRepair() {
        let meal = FoodLogDraft(
            displayName: "chicken breast",
            components: [
                FoodComponent(
                    name: "cooked skinless chicken breast",
                    quantity: 300,
                    unit: "g",
                    calories: 400,
                    protein: 90,
                    carbs: 0,
                    fat: 10,
                    sourceText: "300g cooked skinless chicken breast"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 300g cooked skinless chicken breast",
            confidence: .high
        )

        XCTAssertFalse(result.repairedMacros)
        XCTAssertEqual(result.mealDraft.components[0].calories, 400)
    }

    // MARK: - Singapore fixtures

    func testSingaporeChickenRiceReferenceWithinRangePassesSanity() throws {
        let fixture = try SingaporeFoodEstimationFixtureSupport.loadFixture()
        guard let caseItem = fixture.cases.first(where: { $0.id == "sg_01_chicken_rice" }) else {
            XCTFail("Missing chicken rice fixture case")
            return
        }

        let meal = validSingaporeChickenRice()
        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: caseItem.inputText,
            confidence: .medium
        )

        XCTAssertTrue(result.isAcceptable)
        XCTAssertTrue(
            SingaporeFoodEstimationFixtureSupport.valueInRange(
                Double(result.mealDraft.totalCalories),
                range: caseItem.caloriesRange
            )
        )
    }

    func testSingaporeUnderestimatedChickenRiceDowngrades() {
        let meal = underestimatedChickenRice()

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log chicken rice",
            confidence: .medium
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.mealDraft.requiresClarificationBeforeLogging)
    }

    func testSingaporeCharKwayTeowFixtureFloor() throws {
        let fixture = try SingaporeFoodEstimationFixtureSupport.loadFixture()
        let caseItem = fixture.cases.first {
            $0.inputText.lowercased().contains("char kway teow")
        }
        XCTAssertNotNil(caseItem)

        let underestimated = FoodLogDraft(
            displayName: "char kway teow",
            components: [
                FoodComponent(name: "noodles", calories: 250, protein: 8, carbs: 30, fat: 10),
                FoodComponent(name: "egg", calories: 70, protein: 6, carbs: 1, fat: 5),
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: underestimated,
            prompt: caseItem?.inputText ?? "log char kway teow",
            confidence: .medium
        )

        XCTAssertFalse(result.isAcceptable)
    }

    private func underestimatedChickenRice() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "chicken rice",
            components: [
                FoodComponent(
                    name: "fragrant rice",
                    quantity: 200,
                    unit: "g",
                    calories: 180,
                    protein: 4,
                    carbs: 38,
                    fat: 1,
                    sourceText: "chicken rice rice"
                ),
                FoodComponent(
                    name: "poached chicken",
                    quantity: 100,
                    unit: "g",
                    calories: 120,
                    protein: 22,
                    carbs: 0,
                    fat: 3,
                    sourceText: "chicken rice chicken"
                ),
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )
    }

    private func validSingaporeChickenRice() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "Hainanese chicken rice",
            components: [
                FoodComponent(
                    name: "fragrant rice",
                    quantity: 200,
                    unit: "g",
                    calories: 260,
                    protein: 5,
                    carbs: 56,
                    fat: 1,
                    sourceText: "chicken rice rice portion"
                ),
                FoodComponent(
                    name: "poached chicken",
                    quantity: 120,
                    unit: "g",
                    calories: 198,
                    protein: 37,
                    carbs: 0,
                    fat: 4.5,
                    sourceText: "chicken rice chicken portion"
                ),
                FoodComponent(
                    name: "chili sauce and chicken oil",
                    quantity: 1,
                    unit: "tbsp",
                    calories: 70,
                    protein: 0,
                    carbs: 2,
                    fat: 7,
                    sourceText: "chicken rice sauce/oil"
                ),
            ],
            confidence: .medium,
            source: .aiTextEstimate,
            assumptions: ["Assumed standard plate with rice, chicken, and sauce/oil."],
            uncertaintyReasons: ["Stall portion size may vary."]
        )
    }
}
