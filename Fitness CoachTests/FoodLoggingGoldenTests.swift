//
//  FoodLoggingGoldenTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodLoggingGoldenTests: XCTestCase {

  // MARK: - Parser

  func testGoldenCase1ParserCountsFourIngredients() {
    assertListedIngredientCount(
      for: FoodLoggingGoldenFixtures.case1,
      expected: 4
    )
  }

  func testGoldenCase2ParserCountsTwoIngredients() {
    assertListedIngredientCount(
      for: FoodLoggingGoldenFixtures.case2,
      expected: 2
    )
  }

  func testGoldenCase3ParserCountsThreeIngredients() {
    assertListedIngredientCount(
      for: FoodLoggingGoldenFixtures.case3,
      expected: 3
    )
  }

  func testGoldenCase4ParserCountsSingleIngredient() {
    assertListedIngredientCount(
      for: FoodLoggingGoldenFixtures.case4,
      expected: 1
    )
  }

  func testGoldenCase5ParserCountsSingleIngredient() {
    assertListedIngredientCount(
      for: FoodLoggingGoldenFixtures.case5,
      expected: 1
    )
  }

  // MARK: - Validator

  func testGoldenCase1ValidResponsePassesValidator() {
    assertValidGatewayResponse(FoodLoggingGoldenFixtures.case1)
  }

  func testGoldenCase1CollapsedResponseFailsValidator() {
    let result = FoodEstimateResponseValidator.validate(
      response: FoodLoggingGoldenFixtures.case1CollapsedResponse,
      prompt: FoodLoggingGoldenFixtures.case1Prompt
    )
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains(where: { $0.contains("collapsed") }))
  }

  func testGoldenCase2ValidResponsePassesValidator() {
    assertValidGatewayResponse(FoodLoggingGoldenFixtures.case2)
  }

  func testGoldenCase3ValidResponsePassesValidator() {
    assertValidGatewayResponse(FoodLoggingGoldenFixtures.case3)
  }

  func testGoldenCase4ValidResponsePassesValidator() {
    assertValidGatewayResponse(FoodLoggingGoldenFixtures.case4)
  }

  func testGoldenCase5ValidResponsePassesValidator() {
    assertValidGatewayResponse(FoodLoggingGoldenFixtures.case5)
  }

  // MARK: - Draft creation / mapping

  func testGoldenCase1DraftCreation() {
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1)

    XCTAssertGreaterThanOrEqual(meal.components.count, 4)
    XCTAssertGreaterThanOrEqual(meal.totalCalories, 600)
    XCTAssertLessThanOrEqual(meal.totalCalories, 750)
    XCTAssertGreaterThanOrEqual(meal.totalProtein, 45)
    XCTAssertLessThanOrEqual(meal.totalProtein, 60)
    XCTAssertGreaterThanOrEqual(meal.totalFat, 18)
    XCTAssertNotEqual(meal.totalCalories, 430)
    XCTAssertGreaterThanOrEqual(meal.totalCalories, 550)
    XCTAssertNil(meal.legacyQuantity)
    XCTAssertNil(meal.legacyUnit)

    let legacy = FoodLogDraftMapper.toLegacyDraft(meal)
    XCTAssertNil(legacy.quantity)
    XCTAssertNil(legacy.unit)
  }

  func testGoldenCase2DraftCreation() {
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case2)

    XCTAssertEqual(meal.components.count, 2)
    XCTAssertGreaterThanOrEqual(meal.totalCalories, 300)
    XCTAssertLessThanOrEqual(meal.totalCalories, 500)
    XCTAssertNil(meal.legacyQuantity)
  }

  func testGoldenCase3DraftCreation() {
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case3)

    XCTAssertEqual(meal.components.count, 3)
    XCTAssertTrue(meal.components.contains(where: { $0.name.lowercased().contains("sauce") }))
    XCTAssertTrue(meal.warnings.joined(separator: " ").lowercased().contains("vague")
      || meal.warnings.joined(separator: " ").lowercased().contains("assumption"))
    XCTAssertTrue(
      meal.confidence == .medium || meal.confidence == .low
    )
    XCTAssertNil(meal.legacyQuantity)
  }

  func testGoldenCase4DraftCreation() {
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case4)

    XCTAssertEqual(meal.components.count, 1)
    XCTAssertGreaterThanOrEqual(meal.totalCalories, 240)
    XCTAssertLessThanOrEqual(meal.totalCalories, 260)
    XCTAssertGreaterThanOrEqual(meal.totalProtein, 45)
    XCTAssertLessThanOrEqual(meal.totalProtein, 48)
    XCTAssertEqual(meal.components.first?.preparationState, "cooked")
    XCTAssertEqual(meal.legacyQuantity, 150)
    XCTAssertEqual(meal.legacyUnit, "g")
  }

  func testGoldenCase5DraftCreation() {
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case5)

    XCTAssertEqual(meal.components.count, 1)
    XCTAssertGreaterThanOrEqual(meal.totalCalories, 170)
    XCTAssertLessThanOrEqual(meal.totalCalories, 200)
    XCTAssertEqual(meal.components.first?.preparationState, "cooked")
    XCTAssertLessThanOrEqual(meal.totalCarbs, 45)
    XCTAssertLessThan(meal.totalCalories, 400, "Should not look like uncooked barley")
  }

  // MARK: - Sanity validator

  func testGoldenCase1PassesSanityValidation() {
    let result = FoodLoggingGoldenFixtures.sanityResult(for: FoodLoggingGoldenFixtures.case1)
    XCTAssertTrue(result.isAcceptable)
    XCTAssertEqual(result.confidence, .high)
  }

  func testGoldenCase1CollapsedFailsSanityValidation() {
    guard let collapsedMeal = FoodLogDraftMapper.primaryMeal(
      from: FoodLoggingGoldenFixtures.case1CollapsedResponse
    ) else {
      return XCTFail("Missing collapsed meal")
    }
    let sanitized = FoodLogDraftNutritionCompleter.sanitize(
      collapsedMeal,
      hintText: FoodLoggingGoldenFixtures.case1Prompt
    )
    let result = NutritionSanityValidator.validate(
      meal: sanitized,
      prompt: FoodLoggingGoldenFixtures.case1Prompt,
      confidence: .medium
    )

    XCTAssertFalse(result.isAcceptable)
    XCTAssertEqual(result.confidence, .low)
    XCTAssertTrue(result.mealDraft.warnings.contains(NutritionSanityResult.underEstimatedUserMessage))
  }

  func testGoldenCase3KeepsMediumOrLowConfidenceWithPortionWarnings() {
    let result = FoodLoggingGoldenFixtures.sanityResult(for: FoodLoggingGoldenFixtures.case3)
    XCTAssertTrue(
      result.confidence == .medium || result.confidence == .low
    )
    let warningText = result.mealDraft.warnings.joined(separator: " ").lowercased()
    XCTAssertTrue(
      warningText.contains("vague")
        || warningText.contains("assumption")
        || warningText.contains("estimated")
    )
  }

  // MARK: - UI prefill

  func testGoldenCase1EditFormPrefill() {
    let form = FoodLoggingGoldenFixtures.editFormState(for: FoodLoggingGoldenFixtures.case1)

    XCTAssertTrue(form.isMultiComponent)
    XCTAssertEqual(form.componentStates.count, 4)
    XCTAssertEqual(form.displayName, "Chicken barley bowl with tiramisu")
    XCTAssertGreaterThanOrEqual(Int(form.totalCaloriesText) ?? 0, 600)
    XCTAssertLessThanOrEqual(Int(form.totalCaloriesText) ?? 0, 750)
    XCTAssertEqual(form.componentStates[0].portionLine, "Chicken breast — 150g cooked")
    XCTAssertEqual(form.componentStates[1].portionLine, "Barley rice — 150g cooked")
    XCTAssertEqual(form.componentStates[2].portionLine, "Sesame/mayo dressing — 1 tbsp")
    XCTAssertEqual(form.componentStates[3].portionLine, "Tiramisu — 55g")
  }

  func testGoldenCase1DoesNotShowWholeMealAmountField() {
    let form = FoodLoggingGoldenFixtures.editFormState(for: FoodLoggingGoldenFixtures.case1)
    XCTAssertTrue(form.isMultiComponent)
    XCTAssertNil(FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case1).legacyQuantity)
  }

  func testGoldenCase2EditFormPrefill() {
    let form = FoodLoggingGoldenFixtures.editFormState(for: FoodLoggingGoldenFixtures.case2)

    XCTAssertTrue(form.isMultiComponent)
    XCTAssertEqual(form.componentStates.count, 2)
    XCTAssertGreaterThanOrEqual(Int(form.totalCaloriesText) ?? 0, 300)
    XCTAssertLessThanOrEqual(Int(form.totalCaloriesText) ?? 0, 500)
  }

  func testGoldenCase3EditFormPrefillIncludesSauceAndPortionWarnings() {
    let form = FoodLoggingGoldenFixtures.editFormState(for: FoodLoggingGoldenFixtures.case3)
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case3)

    XCTAssertEqual(form.componentStates.count, 3)
    XCTAssertTrue(form.componentStates.contains(where: { $0.name.lowercased().contains("sauce") }))
    XCTAssertTrue(
      meal.warnings.joined(separator: " ").lowercased().contains("vague")
        || meal.warnings.joined(separator: " ").lowercased().contains("assumption")
    )
  }

  func testGoldenCase4EditFormPrefillSingleComponent() {
    let form = FoodLoggingGoldenFixtures.editFormState(for: FoodLoggingGoldenFixtures.case4)

    XCTAssertFalse(form.isMultiComponent)
    XCTAssertEqual(form.componentStates.count, 1)
    XCTAssertGreaterThanOrEqual(Int(form.componentStates[0].caloriesText) ?? 0, 240)
    XCTAssertLessThanOrEqual(Int(form.componentStates[0].caloriesText) ?? 0, 260)
    XCTAssertGreaterThanOrEqual(Double(form.componentStates[0].proteinText) ?? 0, 45)
    XCTAssertLessThanOrEqual(Double(form.componentStates[0].proteinText) ?? 0, 48)
  }

  func testGoldenCase5EditFormPrefillCookedBarleyRice() {
    let form = FoodLoggingGoldenFixtures.editFormState(for: FoodLoggingGoldenFixtures.case5)

    XCTAssertFalse(form.isMultiComponent)
    XCTAssertGreaterThanOrEqual(Int(form.componentStates[0].caloriesText) ?? 0, 170)
    XCTAssertLessThanOrEqual(Int(form.componentStates[0].caloriesText) ?? 0, 200)
    XCTAssertEqual(form.componentStates[0].portionLine, "Barley rice — 150g cooked")
  }

  func testGoldenCase3PendingCopyMentionsPortionUncertainty() {
    let meal = FoodLoggingGoldenFixtures.sanitizedMeal(for: FoodLoggingGoldenFixtures.case3)
    let message = CoachResponseBuilder.aiFoodEstimatePending(
      mealDraft: meal,
      confidence: .medium,
      originalText: FoodLoggingGoldenFixtures.case3Prompt
    )

    XCTAssertTrue(message.lowercased().contains("sauce") || message.contains("Sauce"))
    XCTAssertTrue(
      meal.warnings.joined(separator: " ").lowercased().contains("vague")
        || message.lowercased().contains("estimated")
        || message.lowercased().contains("assumption")
    )
  }

  // MARK: - Helpers

  private func assertListedIngredientCount(for goldenCase: FoodLoggingGoldenFixtures.GoldenCase, expected: Int) {
    XCTAssertEqual(
      FoodListedIngredientCounter.count(in: goldenCase.prompt),
      expected,
      "Parser ingredient count mismatch for \(goldenCase.id)"
    )
  }

  private func assertValidGatewayResponse(_ goldenCase: FoodLoggingGoldenFixtures.GoldenCase) {
    let result = FoodEstimateResponseValidator.validate(
      response: goldenCase.gatewayResponse,
      prompt: goldenCase.prompt
    )
    XCTAssertTrue(result.isValid, "Expected valid response for \(goldenCase.id): \(result.errors)")
  }
}
