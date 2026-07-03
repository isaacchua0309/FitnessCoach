//
//  PlanTransformationSummaryBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Transformation summary builder tests.
//

import XCTest
@testable import Fitness_Coach

final class PlanTransformationSummaryBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    func testFatLossSummaryIncludesChangeAndTimeline() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"
        formState.weightLossPaceChoice = .advanced
        formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "1")

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let summary = PlanTransformationSummaryBuilder.build(
            projection: projection,
            currentWeightKg: 80,
            goalWeightKg: 70,
            goalType: .loseFat
        )

        XCTAssertEqual(summary.currentWeight, "80 kg")
        XCTAssertEqual(summary.targetWeight, "70 kg")
        XCTAssertEqual(summary.totalChange, "10 kg between now and your goal.")
        XCTAssertEqual(summary.estimatedDuration, "About 10 weeks")
        XCTAssertEqual(summary.estimatedFinish, "March 2026")
        XCTAssertTrue(summary.isComplete)
    }

    func testMaintenanceSummaryOmitsDurationWhenNotApplicable() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.currentWeightKg = 75
        profile.goalWeightKg = 75
        let formState = PlanFormState(profile: profile)

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .maintain,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let summary = PlanTransformationSummaryBuilder.build(
            projection: projection,
            currentWeightKg: 75,
            goalWeightKg: 75,
            goalType: .maintain
        )

        XCTAssertEqual(summary.totalChange, FormaProductCopy.PlanEditHero.maintainingTarget)
        XCTAssertNil(summary.estimatedDuration)
    }
}
