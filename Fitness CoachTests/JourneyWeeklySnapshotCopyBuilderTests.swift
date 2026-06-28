//
//  JourneyWeeklySnapshotCopyBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyWeeklySnapshotCopyBuilderTests: XCTestCase {

    func testLockedTrainingShowsConnectAppleHealthCopy() {
        let review = makeReview(training: .locked)

        let trainingRow = JourneyWeeklySnapshotCopyBuilder.rows(for: review).first { $0.id == "training" }
        XCTAssertEqual(trainingRow?.detail, FormaProductCopy.Journey.WeeklySnapshot.trainingConnectAppleHealth)
    }

    func testProteinUsesCompactDayCount() {
        var review = makeReview(training: .hidden)
        review.proteinGoalDays = 2
        review.proteinGoalDaysTotal = 5

        let protein = JourneyWeeklySnapshotCopyBuilder.rows(for: review).first { $0.id == "protein" }
        XCTAssertEqual(
            protein?.detail,
            FormaProductCopy.Journey.WeeklySnapshot.daysAchieved(achieved: 2, total: 5)
        )
        XCTAssertFalse(protein?.detail.contains("Behind") == true)
    }

    func testWaterNotStartedShowsCompactStatus() {
        var review = makeReview(training: .hidden)
        review.proteinGoalDaysTotal = 3
        review.waterGoalDaysTotal = 3

        let water = JourneyWeeklySnapshotCopyBuilder.rows(for: review).first { $0.id == "water" }
        XCTAssertEqual(water?.detail, FormaProductCopy.Journey.WeeklySnapshot.statusNotStarted)
    }

    func testCalorieDeficitMapsToUnderTarget() {
        var review = makeReview(training: .hidden)
        review.averageCalorieDeficit = 120

        let calories = JourneyWeeklySnapshotCopyBuilder.rows(for: review).first { $0.id == "calories" }
        XCTAssertEqual(calories?.detail, FormaProductCopy.Journey.WeeklySnapshot.statusUnderTarget)
    }

    func testConnectedTrainingUsesWorkoutDayLine() {
        let detail = JourneyWeeklySnapshotCopyBuilder.trainingDetail(for: .connected(
            workoutDays: 2,
            averageCaloriesBurned: 300,
            averageTrainingDurationMinutes: 40
        ))

        XCTAssertEqual(
            detail,
            FormaProductCopy.Journey.WeeklySnapshot.workoutDaysLine(days: 2)
        )
    }

    private func makeReview(training: JourneyWeeklyTrainingStatus) -> JourneyWeeklyReviewState {
        JourneyWeeklyReviewState(
            foodLoggedDays: 0,
            foodLoggedDaysTotal: 7,
            proteinGoalDays: 0,
            proteinGoalDaysTotal: 7,
            waterGoalDays: 0,
            waterGoalDaysTotal: 7,
            trainingDays: training.workoutDays ?? 0,
            expectedTrainingDays: 0,
            training: training,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: 0,
            calorieAdherenceDaysTotal: 7,
            strongestPositiveSignal: "",
            weakestSignal: "",
            weekSummaryCopy: "",
            averageCalorieDeficit: nil
        )
    }
}
