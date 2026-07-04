//
//  PlanPaceOutcomeBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Pace outcome card builder tests.
//

import XCTest
@testable import Fitness_Coach

final class PlanPaceOutcomeBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    func testOptionsIncludeAllPaceChoicesWithFriendlyTitles() throws {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"

        let options = PlanPaceOutcomeBuilder.options(
            formState: formState,
            goalType: .loseFat,
            advancedDraft: .default,
            weightKg: 80,
            goalWeightKg: 70,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(options.count, WeightLossPaceChoice.allCases.count)

        let gentle = try XCTUnwrap(options.first { $0.choice == .gentle })
        XCTAssertEqual(gentle.title, FormaProductCopy.PlanEditTarget.paceGentleTitle)
        XCTAssertEqual(gentle.subtitle, FormaProductCopy.PlanEditTarget.paceGentleSubtitle)
        XCTAssertFalse(gentle.difficultyLabel.contains("gentle"))
        XCTAssertFalse(gentle.difficultyLabel.contains("aggressiveDeficit"))
        XCTAssertNotNil(gentle.weeklyChangeLabel)
        XCTAssertNotNil(gentle.coachingDescription)
    }

    func testModeratePaceIncludesEstimatedFinish() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"
        formState.weightLossPaceChoice = .moderate

        let presentation = PlanPaceOutcomeBuilder.presentation(
            choice: .moderate,
            formState: formState,
            goalType: .loseFat,
            advancedDraft: .default,
            weightKg: 80,
            goalWeightKg: 70,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNotNil(presentation.estimatedFinishLabel)
        XCTAssertTrue(presentation.isSelectable)
    }

    func testAdvancedWithZeroAmountIsNotSelectable() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"

        let presentation = PlanPaceOutcomeBuilder.presentation(
            choice: .advanced,
            formState: formState,
            goalType: .loseFat,
            advancedDraft: WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0"),
            weightKg: 80,
            goalWeightKg: 70,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertFalse(presentation.isSelectable)
        XCTAssertNotNil(presentation.validationError)
    }

    func testAdvancedIncludesImpactPreviewsWhenValid() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"

        let presentation = PlanPaceOutcomeBuilder.presentation(
            choice: .advanced,
            formState: formState,
            goalType: .loseFat,
            advancedDraft: WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.5"),
            weightKg: 80,
            goalWeightKg: 70,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNotNil(presentation.adherenceEstimate)
        XCTAssertNotNil(presentation.recoveryImpact)
        XCTAssertNotNil(presentation.hungerImpact)
        XCTAssertNotNil(presentation.energyBalanceLabel)
    }
}
