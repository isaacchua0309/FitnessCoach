//
//  PlanAssumptionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAssumptionsTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testAssumptionsRenderCorrectly() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.assumptions

        XCTAssertEqual(assumptions.sectionTitle, "Plan Assumptions")
        XCTAssertEqual(assumptions.rows.map(\.id), [
            "age", "height", "weight", "sex", "activity", "goalWeight"
        ])
        XCTAssertEqual(assumptions.rows[0].label, "Age")
        XCTAssertEqual(assumptions.rows[0].value, "28")
        XCTAssertEqual(assumptions.rows[1].value, "168 cm")
        XCTAssertEqual(assumptions.rows[2].value, "90 kg")
        XCTAssertEqual(assumptions.rows[3].value, "Female")
        XCTAssertEqual(assumptions.rows[4].value, "Moderately active")
        XCTAssertEqual(assumptions.rows[5].value, "75 kg")
        XCTAssertFalse(assumptions.rows.contains(where: \.isMissing))
    }

    func testMissingAssumptionsFallback() {
        var profile = PlanMissionControlFixtures.legacyAgeOnlyProfile
        profile.heightCm = 0
        profile.currentWeightKg = 0
        profile.goalWeightKg = 0
        profile.age = 0
        profile.birthDate = nil

        let rows = PlanAssumptionsStateBuilder.assumptionRows(
            profile: profile,
            asOf: referenceDate
        )
        let missingRows = rows.filter(\.isMissing).map(\.id)

        XCTAssertEqual(missingRows, ["age", "height", "weight", "goalWeight"])
        XCTAssertEqual(rows.first { $0.id == "age" }?.value, "Not set")
        XCTAssertEqual(rows.first { $0.id == "height" }?.value, "Not set")
        XCTAssertEqual(rows.first { $0.id == "weight" }?.value, "Not set")
        XCTAssertEqual(rows.first { $0.id == "goalWeight" }?.value, "Not set")
        XCTAssertEqual(rows.first { $0.id == "sex" }?.value, "Female")
    }

    func testUpdateActivityLinkWorks() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.assumptions

        XCTAssertEqual(
            assumptions.adjustActivityTitle,
            FormaProductCopy.PlanMissionControl.adjustActivity
        )
        XCTAssertEqual(assumptions.adjustActivityTitle, "Update activity level")
        XCTAssertTrue(assumptions.accessibilitySummary.contains("Update activity level"))
    }

    func testAssumptionsAccessibilitySummaryIncludesAllRows() {
        let summary = PlanMissionControlFixtures.loseDashboard.assumptions.accessibilitySummary

        XCTAssertTrue(summary.contains("Age"))
        XCTAssertTrue(summary.contains("Height"))
        XCTAssertTrue(summary.contains("Weight"))
        XCTAssertTrue(summary.contains("Activity"))
        XCTAssertTrue(summary.contains("Goal weight"))
        XCTAssertFalse(summary.contains("Apple Health"))
    }
}
