//
//  PlanEditFinalPlanSummaryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanEditFinalPlanSummaryBuilderTests: XCTestCase {

    func testNoChangesShowsUpToDateHeadline() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let formState = PlanFormState(profile: baseline)
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)

        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baseline,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review
        )

        XCTAssertTrue(summary.isUpToDate)
        XCTAssertEqual(
            summary.headline,
            FormaProductCopy.PlanEditReview.planUpToDateHeadline
        )
        XCTAssertTrue(summary.inputChanges.isEmpty)
        XCTAssertFalse(summary.goal.isEmpty)
        XCTAssertNotNil(summary.calories)
    }

    func testChangesShowReadyHeadlineAndFriendlySummaries() {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"

        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)

        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baseline,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review
        )

        XCTAssertFalse(summary.isUpToDate)
        XCTAssertEqual(
            summary.headline,
            FormaProductCopy.PlanEditReview.planReadyHeadline
        )
        XCTAssertEqual(summary.inputChanges.count, 1)
        XCTAssertTrue(summary.inputChanges.first?.summary.contains("now") == true)
    }

    func testTodayChangesNoteWhenTargetsMatchBaseline() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let formState = PlanFormState(profile: baseline)
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)

        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baseline,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review
        )

        XCTAssertFalse(summary.todayChanges.isEmpty)
        XCTAssertEqual(
            summary.todayNote,
            FormaProductCopy.PlanEditReview.todayNoChangeNote
        )
    }
}
