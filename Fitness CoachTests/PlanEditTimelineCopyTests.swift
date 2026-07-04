//
//  PlanEditTimelineCopyTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan estimated completion formatting.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditTimelineCopyTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
    }

    func testEstimatedFinishLabelFormatsMonthYear() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        XCTAssertEqual(
            PlanEditTimelineCopy.estimatedFinishLabel(for: date, calendar: calendar),
            FormaProductCopy.PlanEditHero.estimatedFinish("March 2026")
        )
    }

    func testMonthYearDisplayStripsLegacyAndCurrentPrefixes() {
        XCTAssertEqual(
            PlanEditTimelineCopy.monthYearDisplay(
                fromCompletionLabel: "Estimated finish: March 2026."
            ),
            "March 2026"
        )
        XCTAssertEqual(
            PlanEditTimelineCopy.monthYearDisplay(
                fromCompletionLabel: "On track for April 2027."
            ),
            "April 2027"
        )
    }

    func testMonthYearDisplayReturnsNilForMissingLabel() {
        XCTAssertNil(PlanEditTimelineCopy.monthYearDisplay(fromCompletionLabel: nil))
        XCTAssertEqual(
            PlanEditTimelineCopy.monthYearDisplay(fromCompletionLabel: "   "),
            ""
        )
    }

    func testProjectionGoalDateOverrideUsesTimelineCopy() {
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let goalDate = calendar.date(from: DateComponents(year: 2027, month: 8, day: 1))!

        let projection = PlanProjectionBuilder.build(
            input: PlanProjectionInput(
                goalType: .loseFat,
                formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
                caloriePreview: nil,
                goalDatePaceOverride: goalDate,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )

        XCTAssertEqual(projection.estimatedCompletionDate, goalDate)
        XCTAssertNil(projection.estimatedWeeks)
        XCTAssertEqual(
            projection.estimatedCompletionLabel,
            PlanEditTimelineCopy.estimatedFinishLabel(for: goalDate, calendar: calendar)
        )
        XCTAssertEqual(
            PlanEditTimelineCopy.monthYearDisplay(fromCompletionLabel: projection.estimatedCompletionLabel),
            "August 2027"
        )
    }
}
