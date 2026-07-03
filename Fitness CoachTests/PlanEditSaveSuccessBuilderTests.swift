//
//  PlanEditSaveSuccessBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Save confirmation copy for Edit Plan.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditSaveSuccessBuilderTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
    }

    func testFatLossSaveSuccessIncludesGoalAndEstimatedDate() {
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let projection = PlanProjectionBuilder.build(
            formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let state = PlanEditSaveSuccessBuilder.build(projection: projection, calendar: calendar)

        XCTAssertEqual(state.title, FormaProductCopy.PlanEditSave.planUpdatedTitle)
        XCTAssertEqual(state.todayLine, FormaProductCopy.PlanEditSave.todayTargetsRegenerated)
        XCTAssertTrue(state.trackLine.contains("Lose Fat"))
        XCTAssertTrue(state.trackLine.contains("by"))
        XCTAssertTrue(state.accessibilitySummary.contains(state.title))
    }

    func testMaintenanceSaveSuccessUsesMaintainingCopy() {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.goalWeightKg = profile.currentWeightKg

        let projection = PlanProjectionBuilder.build(
            formState: PlanFormState(profile: profile),
            goalType: .maintain
        )

        let state = PlanEditSaveSuccessBuilder.build(projection: projection)

        XCTAssertEqual(
            state.trackLine,
            FormaProductCopy.PlanEditSave.onTrackMaintaining
        )
    }

    func testGoalOnlyTrackLineWhenNoEstimatedDate() {
        let projection = PlanProjectionBuilder.build(
            formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
            goalType: .gainMuscle
        )

        let state = PlanEditSaveSuccessBuilder.build(projection: projection)

        XCTAssertEqual(
            state.trackLine,
            FormaProductCopy.PlanEditSave.onTrackForGoalOnly("Gain Muscle")
        )
    }
}
