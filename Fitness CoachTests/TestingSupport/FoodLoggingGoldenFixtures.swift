//
//  FoodLoggingGoldenFixtures.swift
//  Fitness CoachTests
//
//  Canonical Coach food logging golden cases for parser, validator, and UI tests.
//

import Foundation
@testable import Fitness_Coach

enum FoodLoggingGoldenFixtures {

  struct CaseID: Equatable {
    static let case1 = "case1_multi_component_bowl"
    static let case2 = "case2_chicken_and_rice"
    static let case3 = "case3_vague_portions_with_sauce"
    static let case4 = "case4_single_chicken_breast"
    static let case5 = "case5_cooked_barley_rice"
  }

  struct GoldenCase {
    let id: String
    let prompt: String
    let gatewayResponse: AIFoodEstimateResponse
    let collapsedResponse: AIFoodEstimateResponse?
    let listedIngredientCount: Int
    let minComponents: Int?
    let exactComponents: Int?
    let caloriesMin: Int?
    let caloriesMax: Int?
    let proteinMin: Double?
    let proteinMax: Double?
    let fatMin: Double?
    let forbiddenCalories: [Int]
    let noMealLevelQuantity: Bool
    let maxConfidence: AIConfidence?
    let requiresSauceComponent: Bool
    let requiresPortionWarning: Bool
    let singleComponent: Bool
    let preparationState: String?
    let maxCarbs: Double?
  }

  static let allCases: [GoldenCase] = [
    case1,
    case2,
    case3,
    case4,
    case5
  ]

  static let case1 = GoldenCase(
    id: CaseID.case1,
    prompt: case1Prompt,
    gatewayResponse: case1Response,
    collapsedResponse: case1CollapsedResponse,
    listedIngredientCount: 4,
    minComponents: 4,
    exactComponents: nil,
    caloriesMin: 600,
    caloriesMax: 750,
    proteinMin: 45,
    proteinMax: 60,
    fatMin: 18,
    forbiddenCalories: [430],
    noMealLevelQuantity: true,
    maxConfidence: nil,
    requiresSauceComponent: false,
    requiresPortionWarning: false,
    singleComponent: false,
    preparationState: nil,
    maxCarbs: nil
  )

  static let case2 = GoldenCase(
    id: CaseID.case2,
    prompt: case2Prompt,
    gatewayResponse: case2Response,
    collapsedResponse: nil,
    listedIngredientCount: 2,
    minComponents: nil,
    exactComponents: 2,
    caloriesMin: 300,
    caloriesMax: 500,
    proteinMin: nil,
    proteinMax: nil,
    fatMin: nil,
    forbiddenCalories: [],
    noMealLevelQuantity: true,
    maxConfidence: nil,
    requiresSauceComponent: false,
    requiresPortionWarning: false,
    singleComponent: false,
    preparationState: nil,
    maxCarbs: nil
  )

  static let case3 = GoldenCase(
    id: CaseID.case3,
    prompt: case3Prompt,
    gatewayResponse: case3Response,
    collapsedResponse: nil,
    listedIngredientCount: 3,
    minComponents: nil,
    exactComponents: 3,
    caloriesMin: nil,
    caloriesMax: nil,
    proteinMin: nil,
    proteinMax: nil,
    fatMin: nil,
    forbiddenCalories: [],
    noMealLevelQuantity: true,
    maxConfidence: .medium,
    requiresSauceComponent: true,
    requiresPortionWarning: true,
    singleComponent: false,
    preparationState: nil,
    maxCarbs: nil
  )

  static let case4 = GoldenCase(
    id: CaseID.case4,
    prompt: case4Prompt,
    gatewayResponse: case4Response,
    collapsedResponse: nil,
    listedIngredientCount: 1,
    minComponents: nil,
    exactComponents: 1,
    caloriesMin: 240,
    caloriesMax: 260,
    proteinMin: 45,
    proteinMax: 48,
    fatMin: nil,
    forbiddenCalories: [],
    noMealLevelQuantity: false,
    maxConfidence: nil,
    requiresSauceComponent: false,
    requiresPortionWarning: false,
    singleComponent: true,
    preparationState: "cooked",
    maxCarbs: nil
  )

  static let case5 = GoldenCase(
    id: CaseID.case5,
    prompt: case5Prompt,
    gatewayResponse: case5Response,
    collapsedResponse: nil,
    listedIngredientCount: 1,
    minComponents: nil,
    exactComponents: 1,
    caloriesMin: 170,
    caloriesMax: 200,
    proteinMin: nil,
    proteinMax: nil,
    fatMin: nil,
    forbiddenCalories: [],
    noMealLevelQuantity: false,
    maxConfidence: nil,
    requiresSauceComponent: false,
    requiresPortionWarning: false,
    singleComponent: true,
    preparationState: "cooked",
    maxCarbs: 45
  )

  // MARK: - Prompts

  static let case1Prompt = """
  log this bowl:
  150g cooked chicken breast
  150g cooked barley rice
  1 tbsp creamy sesame/mayo dressing
  50-60g tiramisu
  """

  static let case2Prompt = "100g chicken breast and one bowl of rice"

  static let case3Prompt = "one chicken breast, one bowl rice, sauce"

  static let case4Prompt = "150g cooked chicken breast"

  static let case5Prompt = "barley rice 150g"

  // MARK: - Gateway responses

  static let case1Response = AIFoodEstimateResponse(
    foodLogDrafts: [case1MealDraft],
    confidence: .high,
    requiresConfirmation: true,
    assistantMessage: "Estimated per ingredient."
  )

  static let case1CollapsedResponse = AIFoodEstimateResponse(
    foodLogDrafts: [
      FoodLogDraft(
        displayName: "bowl",
        components: [
          FoodComponent(
            name: "bowl with chicken and rice",
            quantity: 150,
            unit: "g",
            preparationState: "cooked",
            calories: 430,
            protein: 38,
            carbs: 42,
            fat: 9,
            sourceText: "log this bowl"
          )
        ],
        confidence: .low,
        source: .aiTextEstimate,
        warnings: ["Estimate failed strict extraction validation. Review portions before logging."]
      )
    ],
    confidence: .low,
    requiresConfirmation: true
  )

  static let case2Response = AIFoodEstimateResponse(
    foodLogDrafts: [case2MealDraft],
    confidence: .medium,
    requiresConfirmation: true
  )

  static let case3Response = AIFoodEstimateResponse(
    foodLogDrafts: [case3MealDraft],
    confidence: .medium,
    requiresConfirmation: true,
    assistantMessage: "Portions are approximate — please review before logging."
  )

  static let case4Response = AIFoodEstimateResponse(
    foodLogDrafts: [case4MealDraft],
    confidence: .high,
    requiresConfirmation: true
  )

  static let case5Response = AIFoodEstimateResponse(
    foodLogDrafts: [case5MealDraft],
    confidence: .high,
    requiresConfirmation: true
  )

  // MARK: - Meal drafts

  static let case1MealDraft = FoodLogDraft(
    displayName: "bowl with chicken breast, barley rice mix, dressing, tiramisu",
    mealType: .lunch,
    components: [
      FoodComponent(
        name: "cooked chicken breast",
        quantity: 150,
        unit: "g",
        preparationState: "cooked",
        calories: 248,
        protein: 46.5,
        carbs: 0,
        fat: 5.4,
        confidence: .high,
        sourceText: "150g cooked chicken breast"
      ),
      FoodComponent(
        name: "cooked barley rice",
        quantity: 150,
        unit: "g",
        preparationState: "cooked",
        calories: 165,
        protein: 4.5,
        carbs: 34,
        fat: 1.1,
        confidence: .high,
        sourceText: "150g cooked barley rice"
      ),
      FoodComponent(
        name: "creamy sesame/mayo dressing",
        quantity: 1,
        unit: "tbsp",
        calories: 95,
        protein: 0.5,
        carbs: 2,
        fat: 10,
        confidence: .medium,
        sourceText: "1 tbsp creamy sesame/mayo dressing"
      ),
      FoodComponent(
        name: "tiramisu",
        quantity: 55,
        unit: "g",
        calories: 180,
        protein: 4,
        carbs: 18,
        fat: 10,
        confidence: .medium,
        sourceText: "50-60g tiramisu"
      )
    ],
    confidence: .high,
    source: .aiTextEstimate
  )

  static let case2MealDraft = FoodLogDraft(
    displayName: "Chicken breast with rice",
    components: [
      FoodComponent(
        name: "cooked chicken breast",
        quantity: 100,
        unit: "g",
        preparationState: "cooked",
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
        confidence: .high,
        sourceText: "100g chicken breast"
      ),
      FoodComponent(
        name: "cooked rice",
        quantity: 200,
        unit: "g",
        preparationState: "cooked",
        calories: 260,
        protein: 5,
        carbs: 56,
        fat: 0.5,
        confidence: .medium,
        sourceText: "one bowl of rice"
      )
    ],
    confidence: .medium,
    source: .aiTextEstimate,
    warnings: ["Assumption: Assumed one bowl of cooked rice is about 200g."]
  )

  static let case3MealDraft = FoodLogDraft(
    displayName: "Chicken breast with rice and sauce",
    components: [
      FoodComponent(
        name: "chicken breast",
        quantity: 150,
        unit: "g",
        preparationState: "cooked",
        calories: 248,
        protein: 46,
        carbs: 0,
        fat: 5,
        confidence: .low,
        sourceText: "one chicken breast"
      ),
      FoodComponent(
        name: "rice",
        quantity: 200,
        unit: "g",
        preparationState: "cooked",
        calories: 260,
        protein: 5,
        carbs: 56,
        fat: 0.5,
        confidence: .low,
        sourceText: "one bowl rice"
      ),
      FoodComponent(
        name: "sauce",
        quantity: 1,
        unit: "tbsp",
        calories: 45,
        protein: 0,
        carbs: 2,
        fat: 4,
        confidence: .low,
        sourceText: "sauce"
      )
    ],
    confidence: .medium,
    source: .aiTextEstimate,
    warnings: [
      "Portions were estimated from vague descriptions.",
      "Assumption: Estimated one chicken breast at 150g cooked.",
      "Assumption: Estimated one bowl of rice at 200g cooked.",
      "Assumption: Estimated one tablespoon of sauce."
    ]
  )

  static let case4MealDraft = FoodLogDraft(
    displayName: "Cooked chicken breast",
    components: [
      FoodComponent(
        name: "cooked chicken breast",
        quantity: 150,
        unit: "g",
        preparationState: "cooked",
        calories: 248,
        protein: 46.5,
        carbs: 0,
        fat: 5.4,
        confidence: .high,
        sourceText: "150g cooked chicken breast"
      )
    ],
    confidence: .high,
    source: .aiTextEstimate
  )

  static let case5MealDraft = FoodLogDraft(
    displayName: "Cooked barley rice",
    components: [
      FoodComponent(
        name: "cooked barley rice",
        quantity: 150,
        unit: "g",
        preparationState: "cooked",
        calories: 180,
        protein: 4.5,
        carbs: 36,
        fat: 1.1,
        confidence: .high,
        sourceText: "barley rice 150g"
      )
    ],
    confidence: .high,
    source: .aiTextEstimate,
    warnings: ["Assumption: Interpreted as 150g cooked barley rice."]
  )

  // MARK: - Pipeline helpers

  static func sanitizedMeal(for goldenCase: GoldenCase) -> FoodLogDraft {
    guard let meal = FoodLogDraftMapper.primaryMeal(from: goldenCase.gatewayResponse) else {
      fatalError("Missing meal for \(goldenCase.id)")
    }
    return FoodLogDraftNutritionCompleter.sanitize(meal, hintText: goldenCase.prompt)
  }

  static func sanityResult(for goldenCase: GoldenCase) -> NutritionSanityResult {
    let sanitized = sanitizedMeal(for: goldenCase)
    return NutritionSanityValidator.validate(
      meal: sanitized,
      prompt: goldenCase.prompt,
      confidence: goldenCase.gatewayResponse.confidence
    )
  }

  static func editFormState(for goldenCase: GoldenCase) -> FoodLogEditFormState {
    FoodLogEditFormState(mealDraft: sanitizedMeal(for: goldenCase))
  }
}
