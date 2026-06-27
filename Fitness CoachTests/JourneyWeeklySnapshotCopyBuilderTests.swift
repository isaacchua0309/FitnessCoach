//
//  JourneyWeeklySnapshotCopyBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Weekly snapshot copy and status mapping.
//

import XCTest
@testable import Fitness_Coach

final class JourneyWeeklySnapshotCopyBuilderTests: XCTestCase {

    func testLockedTrainingShowsConnectAppleHealthCopy() {
        let snapshot = JourneyWeeklySnapshot(
            training: .locked,
            proteinDaysAchieved: 0,
            proteinDaysTotal: 0,
            waterDaysAchieved: 0,
            waterDaysTotal: 0,
            averageCalorieDeficit: nil
        )

        let trainingRow = JourneyWeeklySnapshotCopyBuilder.rows(for: snapshot).first { $0.id == "training" }
        XCTAssertEqual(trainingRow?.detail, FormaProductCopy.Journey.WeeklySnapshot.trainingConnectAppleHealth)
    }

    func testProteinUsesCompactDayCount() {
        let snapshot = JourneyWeeklySnapshot(
            training: .hidden,
            proteinDaysAchieved: 2,
            proteinDaysTotal: 5,
            waterDaysAchieved: 0,
            waterDaysTotal: 0,
            averageCalorieDeficit: nil
        )

        let protein = JourneyWeeklySnapshotCopyBuilder.rows(for: snapshot).first { $0.id == "protein" }
        XCTAssertEqual(
            protein?.detail,
            FormaProductCopy.Journey.WeeklySnapshot.daysAchieved(achieved: 2, total: 5)
        )
        XCTAssertFalse(protein?.detail.contains("Behind") == true)
    }

    func testWaterNotStartedShowsCompactStatus() {
        let snapshot = JourneyWeeklySnapshot(
            training: .hidden,
            proteinDaysAchieved: 0,
            proteinDaysTotal: 3,
            waterDaysAchieved: 0,
            waterDaysTotal: 3,
            averageCalorieDeficit: nil
        )

        let water = JourneyWeeklySnapshotCopyBuilder.rows(for: snapshot).first { $0.id == "water" }
        XCTAssertEqual(water?.detail, FormaProductCopy.Journey.WeeklySnapshot.statusNotStarted)
    }

    func testCalorieDeficitMapsToUnderTarget() {
        let snapshot = JourneyWeeklySnapshot(
            training: .hidden,
            proteinDaysAchieved: 0,
            proteinDaysTotal: 0,
            waterDaysAchieved: 0,
            waterDaysTotal: 0,
            averageCalorieDeficit: 120
        )

        let calories = JourneyWeeklySnapshotCopyBuilder.rows(for: snapshot).first { $0.id == "calories" }
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
}
