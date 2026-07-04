//
//  NutritionEstimateCardTrustTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NutritionEstimateCardTrustTests: XCTestCase {

    func testEstimateOnlyIntentDoesNotIncludeLogAction() {
        let response = sampleResponse()
        let card = NutritionEstimateCardFormatter.cardState(
            from: response,
            dailyLog: nil,
            suppressLogAction: true
        )

        XCTAssertFalse(card.allowsLogging)
        XCTAssertFalse(card.suggestedActions.contains { $0.type == .logMeal })
        XCTAssertNil(card.logMealPayload)
    }

    func testEstimateCardShowsLikelyRange() {
        let response = NutritionEstimateResponse(
            foodName: "Chicken rice",
            caloriesKcal: 650,
            caloriesRangeLowerKcal: 580,
            caloriesRangeUpperKcal: 720,
            confidenceLevel: .medium,
            assumptions: ["Standard hawker portion"]
        )

        let card = NutritionEstimateCardFormatter.cardState(from: response, dailyLog: nil)
        let trust = XCTUnwrap(card.trustPresentation)

        XCTAssertEqual(trust.aboutCaloriesLine, "About 650 kcal")
        XCTAssertEqual(trust.likelyRangeLine, "Likely range: 580–720 kcal")
        XCTAssertEqual(card.calorieRange?.lowerBound, 580)
        XCTAssertEqual(card.calorieRange?.upperBound, 720)
    }

    func testEstimateCardDerivesRangeWhenBackendOmitsBounds() {
        let response = NutritionEstimateResponse(
            foodName: "Pad thai",
            caloriesKcal: 500,
            confidenceLevel: .medium
        )

        let card = NutritionEstimateCardFormatter.cardState(from: response, dailyLog: nil)
        let trust = XCTUnwrap(card.trustPresentation)

        XCTAssertNotNil(trust.likelyRangeLine)
        XCTAssertTrue(trust.likelyRangeLine?.contains("Likely range:") == true)
        XCTAssertNotNil(card.calorieRange?.lowerBound)
        XCTAssertNotNil(card.calorieRange?.upperBound)
    }

    func testLogActionTransfersRangeAndTrustMetadataIntoPendingDraft() {
        let response = NutritionEstimateResponse(
            foodName: "Pad thai",
            caloriesKcal: 520,
            caloriesRangeLowerKcal: 450,
            caloriesRangeUpperKcal: 620,
            proteinGrams: 18,
            confidenceLevel: .low,
            assumptions: ["Regular portion"],
            uncertaintyReasons: ["Oil amount unclear"],
            suggestedClarifications: ["Was this a large portion?"],
            primaryUncertainty: "Oil amount",
            requiresClarificationBeforeLogging: true,
            riskLevel: .high
        )
        let card = NutritionEstimateCardFormatter.cardState(from: response, dailyLog: nil)
        let logAction = XCTUnwrap(card.logMealPayload)

        let draft = XCTUnwrap(
            NutritionSuggestedActionHandler.mealDraft(from: XCTUnwrap(card.sourceResponse), action: logAction)
        )
        let normalized = FoodEstimateTrustNormalizer.normalize(draft, prompt: "Log Pad thai")

        XCTAssertEqual(normalized.totalCalories, 520)
        XCTAssertEqual(normalized.calorieRangeLower, 450)
        XCTAssertEqual(normalized.calorieRangeUpper, 620)
        XCTAssertEqual(normalized.assumptions, ["Regular portion"])
        XCTAssertEqual(normalized.primaryUncertainty, "Oil amount")
        XCTAssertTrue(normalized.requiresClarificationBeforeLogging)
        XCTAssertEqual(normalized.riskLevel, .high)
    }

    func testDontLogPromptSuppressesLogChip() {
        let response = sampleResponse(logActionTitle: "Log Chicken rice")
        let outcome = NutritionEstimateResponseParser.parseEstimate(
            response,
            dailyLog: nil,
            prompt: "estimate pad thai but don't log"
        )

        guard case .estimate(let card) = outcome else {
            return XCTFail("Expected estimate card")
        }

        XCTAssertFalse(card.allowsLogging)
        XCTAssertFalse(card.suggestedActions.contains { $0.type == .logMeal })
    }

    func testLowConfidenceEstimateCardCopyIsHonest() {
        let response = NutritionEstimateResponse(
            foodName: "Laksa",
            caloriesKcal: 520,
            caloriesRangeLowerKcal: 420,
            caloriesRangeUpperKcal: 650,
            confidenceLevel: .low,
            confidenceReason: "Portion size unclear",
            assumptions: ["Regular bowl"],
            uncertaintyReasons: ["Coconut milk amount varies"],
            primaryUncertainty: "Portion size",
            requiresClarificationBeforeLogging: true
        )

        let card = NutritionEstimateCardFormatter.cardState(from: response, dailyLog: nil)
        let trust = XCTUnwrap(card.trustPresentation)

        XCTAssertEqual(trust.confidenceLine, "Confidence: Low")
        XCTAssertEqual(
            trust.lowConfidenceWarning,
            FormaProductCopy.Coach.pendingLowConfidenceWarning
        )
        XCTAssertEqual(trust.biggestUncertaintyLine, "Main uncertainty: Portion size")
        XCTAssertFalse(trust.assumptionLines.isEmpty)
    }

    func testLogActionUsesTrustAwareTitle() {
        let response = sampleResponse(logActionTitle: "Log Meal")
        let card = NutritionEstimateCardFormatter.cardState(from: response, dailyLog: nil)

        let logAction = XCTUnwrap(card.logMealPayload)
        XCTAssertEqual(logAction.title, FormaProductCopy.Coach.logEstimatePending)
    }

    func testComparisonCardStillBuildsFromResponse() {
        let response = NutritionComparisonResponse(
            leftItem: NutritionComparisonItem(
                foodName: "Big Mac",
                caloriesKcal: 550,
                caloriesRangeLowerKcal: 520,
                caloriesRangeUpperKcal: 580
            ),
            rightItem: NutritionComparisonItem(
                foodName: "McSpicy",
                caloriesKcal: 540
            ),
            coachPick: "Similar calories."
        )

        let card = NutritionEstimateCardFormatter.comparisonCardState(from: response)

        XCTAssertEqual(card.leftItem.foodName, "Big Mac")
        XCTAssertEqual(card.leftCaloriesDisplay, "About 550 kcal")
        XCTAssertEqual(card.rightCaloriesDisplay, "About 540 kcal")
    }

    func testEstimateOnlyRouteDoesNotAutoCreatePendingConfirmation() {
        let guarded = CoachIntentPhraseGuard.applyGuards(
            to: CoachIntentResult(
                intent: .logFood,
                confidence: 0.9,
                domain: .nutrition,
                requiresAppMutation: true,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false
            ),
            text: "estimate pad thai but don't log"
        )

        XCTAssertEqual(guarded.intent, .nutritionEstimateQuery)
        XCTAssertFalse(guarded.requiresAppMutation)
        XCTAssertNil(guarded.action)
    }

    // MARK: - Fixtures

    private func sampleResponse(logActionTitle: String = "Log estimate") -> NutritionEstimateResponse {
        NutritionEstimateResponse(
            foodName: "Chicken rice",
            caloriesKcal: 650,
            caloriesRangeLowerKcal: 580,
            caloriesRangeUpperKcal: 720,
            proteinGrams: 35,
            confidenceLevel: .medium,
            assumptions: ["Standard hawker portion"],
            suggestedActions: [
                NutritionSuggestedAction(title: logActionTitle, type: .logMeal, payload: ["foodName": "Chicken rice"])
            ]
        )
    }
}
