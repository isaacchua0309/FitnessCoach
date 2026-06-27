//
//  EmptyStateCopyTests.swift
//  Fitness CoachTests
//
//  Forma — Guardrails for standardized empty-state copy.
//

import XCTest
@testable import Fitness_Coach

final class EmptyStateCopyTests: XCTestCase {

    func testMealsEmptyStateUsesCentralizedCopy() {
        XCTAssertEqual(FormaProductCopy.Today.mealsEmptyTitle, FormaProductCopy.EmptyState.Meals.title)
        XCTAssertEqual(FormaProductCopy.Today.mealsEmptyBody, FormaProductCopy.EmptyState.Meals.body)
        XCTAssertEqual(FormaProductCopy.Journey.weightTrendEmpty, FormaProductCopy.EmptyState.WeightTrend.body)
        XCTAssertEqual(FormaProductCopy.Journey.momentumEmptyBody, FormaProductCopy.EmptyState.Consistency.body)
        XCTAssertEqual(FormaProductCopy.Coach.emptyIntro, FormaProductCopy.EmptyState.CoachConversation.body)
    }

    func testEmptyStateCopyAvoidsShameLanguage() {
        let samples = [
            FormaProductCopy.EmptyState.Meals.title,
            FormaProductCopy.EmptyState.Meals.body,
            FormaProductCopy.EmptyState.WeightTrend.body,
            FormaProductCopy.EmptyState.Consistency.body,
            FormaProductCopy.EmptyState.CoachConversation.body,
            FormaProductCopy.EmptyState.TrainingInsights.connectedEmptyBody
        ]

        for sample in samples {
            XCTAssertFalse(sample.localizedCaseInsensitiveContains("behind"))
            XCTAssertFalse(sample.localizedCaseInsensitiveContains("failed"))
            XCTAssertFalse(sample.localizedCaseInsensitiveContains("locked"))
        }
    }
}
