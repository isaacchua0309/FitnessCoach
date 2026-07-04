//
//  CoachCorrectionMemoryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachCorrectionMemoryBuilderTests: XCTestCase {

    func testIncludesUserEditedBeforeConfirmFoodLogs() {
        let now = Date()
        let event = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Chicken breast",
                    calories: 330,
                    proteinGrams: 62,
                    carbsGrams: 0,
                    fatGrams: 7,
                    userEditedBeforeConfirm: true
                )
            ),
            occurredAt: now
        )

        let assumptions = CoachCorrectionMemoryBuilder.makeAssumptions(
            from: [event],
            now: now
        )

        XCTAssertEqual(assumptions.count, 1)
        XCTAssertTrue(assumptions[0].detail.contains("edited an AI estimate"))
        XCTAssertTrue(assumptions[0].detail.contains("Chicken breast"))
    }

    func testIncludesFoodEditedEvents() {
        let now = Date()
        let event = CoachTimelineEvent.make(
            type: .foodEdited,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Chicken rice",
                    calories: 680,
                    proteinGrams: 35,
                    carbsGrams: 80,
                    fatGrams: 20,
                    isEdit: true
                )
            ),
            occurredAt: now
        )

        let assumptions = CoachCorrectionMemoryBuilder.makeAssumptions(
            from: [event],
            now: now
        )

        XCTAssertEqual(assumptions.count, 1)
        XCTAssertTrue(assumptions[0].detail.contains("corrected a logged meal"))
    }

    func testIgnoresUneditedFoodLogs() {
        let now = Date()
        let event = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Kopi o",
                    calories: 100,
                    proteinGrams: 0,
                    carbsGrams: 10,
                    fatGrams: 2,
                    userEditedBeforeConfirm: false
                )
            ),
            occurredAt: now
        )

        let assumptions = CoachCorrectionMemoryBuilder.makeAssumptions(
            from: [event],
            now: now
        )

        XCTAssertTrue(assumptions.isEmpty)
    }
}
