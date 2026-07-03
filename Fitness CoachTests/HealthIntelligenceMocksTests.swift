//
//  HealthIntelligenceMocksTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceMocksTests: XCTestCase {

    #if DEBUG
    func testMockReadyDayHasHighRecoveryAndNoWorkout() {
        let snapshot = HealthIntelligenceSnapshot.mockReadyDay()

        XCTAssertEqual(snapshot.recovery.status, .ready)
        XCTAssertEqual(snapshot.recovery.score, 84)
        XCTAssertNil(snapshot.workout)
        XCTAssertEqual(snapshot.activity.steps, 8_450)
        XCTAssertNil(snapshot.weeklyReview)
    }

    func testMockWorkoutDayIncludesStrengthWorkoutAndProteinAction() {
        let snapshot = HealthIntelligenceSnapshot.mockWorkoutDay()

        XCTAssertEqual(snapshot.workout?.primaryWorkoutType, .strength)
        XCTAssertEqual(snapshot.workout?.title, "Strength training")
        XCTAssertEqual(snapshot.nutritionAdjustment.priority, 6)
        XCTAssertEqual(snapshot.nextBestAction.reason, .postWorkoutRecovery)
        XCTAssertEqual(snapshot.nextBestAction.destination, .logMeal)
    }

    func testMockLowRecoveryDaySurfacesRecoveryAction() {
        let snapshot = HealthIntelligenceSnapshot.mockLowRecoveryDay()

        XCTAssertEqual(snapshot.recovery.status, .low)
        XCTAssertLessThan(snapshot.recovery.score ?? 100, 55)
        XCTAssertEqual(snapshot.nextBestAction.reason, .lowRecovery)
        XCTAssertEqual(snapshot.nextBestAction.destination, .viewRecovery)
    }

    func testMockNoHealthDataIsDisconnectedState() {
        let snapshot = HealthIntelligenceSnapshot.mockNoHealthData()

        XCTAssertEqual(snapshot.recovery.status, .unknown)
        XCTAssertEqual(snapshot.activity, .empty)
        XCTAssertEqual(snapshot.planConfidence, .unknown)
        XCTAssertEqual(snapshot.nextBestAction.reason, .connectHealth)
    }

    func testMockWeeklyReviewIncludesStrongWeekSummary() {
        let snapshot = HealthIntelligenceSnapshot.mockWeeklyReview()

        XCTAssertNotNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.weeklyReview?.title, "Strong week")
        XCTAssertEqual(snapshot.weeklyReview?.stats.totalWorkouts, 4)
        XCTAssertEqual(snapshot.weeklyReview?.confidence, .high)
    }

    func testComponentMocksAreDeterministic() {
        XCTAssertEqual(RecoverySummary.mockReady.score, 84)
        XCTAssertEqual(RecoverySummary.mockLow.status, .low)
        XCTAssertEqual(WorkoutSummary.mockStrengthWorkout().demand, .high)
        XCTAssertEqual(TrainingLoadSummary.mockNormal.status, .normal)
        XCTAssertEqual(AdaptiveNutritionSummary.mockPostWorkout.priority, 6)
        XCTAssertEqual(NextBestAction.mockLogProtein().id, "mock-log-protein")
        XCTAssertEqual(WeeklyHealthReview.mockStrongWeek().wins.count, 2)
    }

    func testSnapshotMocksUseStableReferenceDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let day = HealthIntelligenceMockFixtures.startOfDay(2026, 7, 3, calendar: calendar)

        let first = HealthIntelligenceSnapshot.mockReadyDay(for: day, calendar: calendar)
        let second = HealthIntelligenceSnapshot.mockReadyDay(for: day, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.date, day)
    }
    #endif
}
