//
//  CoachPendingFoodEstimatePresentationTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachPendingFoodEstimatePresentationTests: XCTestCase {

    func testPendingCardWithoutRangeStillRenders() {
        let presentation = presentationForChickenDraft()

        XCTAssertEqual(presentation.estimatedCaloriesLine, "Estimated: about 330 kcal")
        XCTAssertNil(presentation.likelyRangeLine)
        XCTAssertEqual(presentation.confidenceLine, "Confidence: High")
        XCTAssertTrue(presentation.accessibilityLabel.contains("Estimated: about 330 kcal"))
    }

    func testPendingCardWithRangeRendersLikelyRange() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.mealDraft.calorieRangeLower = 300
        draft.mealDraft.calorieRangeUpper = 380

        let presentation = CoachPendingFoodEstimatePresentationBuilder.presentation(for: draft)

        XCTAssertEqual(presentation.likelyRangeLine, "Likely range: 300–380 kcal")
        XCTAssertTrue(presentation.accessibilityLabel.contains("Likely range: 300–380 kcal"))
    }

    func testLowConfidenceWarningRenders() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.confidence = .low
        draft.mealDraft.confidence = .low

        let presentation = CoachPendingFoodEstimatePresentationBuilder.presentation(for: draft)

        XCTAssertEqual(
            presentation.lowConfidenceWarning,
            FormaProductCopy.Coach.pendingLowConfidenceWarning
        )
    }

    func testAssumptionsRenderAndCollapseExtras() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.mealDraft.assumptions = [
            "Rice assumed about 1 bowl",
            "Chicken assumed roasted with skin",
            "Sauce/oil included as moderate amount",
            "Extra assumption should collapse"
        ]

        let presentation = CoachPendingFoodEstimatePresentationBuilder.presentation(for: draft)

        XCTAssertEqual(presentation.assumptionLines.count, 3)
        XCTAssertEqual(presentation.hiddenAssumptionCount, 1)
    }

    func testLongAssumptionsStayWithinVisibleLimit() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.mealDraft.assumptions = (1...6).map {
            "Assumption \($0): a very long portion description that should not break layout"
        }

        let presentation = CoachPendingFoodEstimatePresentationBuilder.presentation(for: draft)

        XCTAssertEqual(presentation.assumptionLines.count, 3)
        XCTAssertEqual(presentation.hiddenAssumptionCount, 3)
    }

    func testMultiComponentBreakdownRenders() {
        let draft = AIFoodConfirmationDraft(
            originalText: "log chicken rice",
            assistantMessage: nil,
            mealDraft: FoodLogDraft(
                displayName: "Chicken rice",
                components: [
                    FoodComponent(name: "Rice", calories: 260, protein: 5, carbs: 55, fat: 1),
                    FoodComponent(name: "Chicken", calories: 280, protein: 35, carbs: 0, fat: 12),
                    FoodComponent(name: "Sauce/oil", calories: 80, protein: 1, carbs: 2, fat: 7)
                ],
                confidence: .low,
                calorieRangeLower: 520,
                calorieRangeUpper: 760,
                assumptions: ["Standard hawker plate"],
                primaryUncertainty: "rice portion and sauce/oil",
                requiresClarificationBeforeLogging: true
            ),
            confidence: .low,
            requiresConfirmation: true
        )

        let presentation = CoachPendingFoodEstimatePresentationBuilder.presentation(for: draft)

        XCTAssertEqual(presentation.componentLines.count, 3)
        XCTAssertTrue(presentation.componentLines.contains("Rice: ~260 kcal"))
        XCTAssertEqual(presentation.mainUncertaintyLine, "Main uncertainty: rice portion and sauce/oil")
        XCTAssertNotNil(presentation.correctionHintLine)
    }

    func testPendingConfirmationSummaryUsesTrustPresentation() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.mealDraft.calorieRangeLower = 300
        draft.mealDraft.calorieRangeUpper = 360
        draft.mealDraft.primaryUncertainty = "cooking method"

        let pending = CoachPendingConfirmation.food(draft)

        XCTAssertTrue(pending.summaryLine.contains("Estimated: about 330 kcal"))
        XCTAssertTrue(pending.summaryLine.contains("Likely range: 300–360 kcal"))
        XCTAssertTrue(pending.summaryLine.contains("Confidence: High"))
        XCTAssertTrue(pending.summaryLine.contains("Main uncertainty: cooking method"))
    }

    private func presentationForChickenDraft() -> CoachPendingFoodEstimatePresentation {
        CoachPendingFoodEstimatePresentationBuilder.presentation(
            for: CoachMutationTestFixtures.chickenConfirmationDraft
        )
    }
}
