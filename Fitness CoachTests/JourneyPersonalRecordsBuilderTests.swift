//
//  JourneyPersonalRecordsBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyPersonalRecordsBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    // Wednesday, 15 Nov 2023
    private let asOf = Date(timeIntervalSince1970: 1_700_044_800)

    func testInsufficientDataShowsLockedMessage() {
        let logs = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }

        let state = build(maturityLogs: logs)

        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.lockedMessage, FormaProductCopy.Journey.PersonalRecords.lockedBody)
        XCTAssertTrue(state.displayRecords.isEmpty)
    }

    func testLongestLoggingStreak() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }

        let state = build(maturityLogs: logs)

        XCTAssertTrue(state.isUnlocked)
        let streak = state.records.first { $0.id == "logging-streak" }
        XCTAssertNotNil(streak)
        XCTAssertEqual(streak?.value, "5 days")
        XCTAssertTrue(streak?.isActive == true)
    }

    func testHighestProteinWeekAverage() {
        let highProteinWeek = (0..<7).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 150, waterMl: 500)
        }
        let lowProteinOlder = (7..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 60, waterMl: 500)
        }

        let state = build(maturityLogs: highProteinWeek + lowProteinOlder)

        let protein = state.records.first { $0.id == "protein-week" }
        XCTAssertNotNil(protein)
        XCTAssertEqual(protein?.value, "150g/day")
        XCTAssertTrue(protein?.subtitle?.contains("7") == true)
    }

    func testLargestWeeklyLossTowardLoseGoal() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }
        let weights = [
            makeWeight(daysAgo: 6, kg: 90),
            makeWeight(daysAgo: 0, kg: 88.7)
        ]

        let state = build(
            maturityLogs: logs,
            allWeights: weights,
            goalDirection: .lose
        )

        let weight = state.records.first { $0.id == "weight-week" }
        XCTAssertNotNil(weight)
        XCTAssertEqual(weight?.title, FormaProductCopy.Journey.PersonalRecords.largestWeeklyLossTitle)
        XCTAssertEqual(weight?.value, "1.3 kg")
    }

    func testLargestWeeklyGainTowardGainGoal() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }
        let weights = [
            makeWeight(daysAgo: 6, kg: 60),
            makeWeight(daysAgo: 0, kg: 61.2)
        ]

        let state = build(
            maturityLogs: logs,
            allWeights: weights,
            goalDirection: .gain
        )

        let weight = state.records.first { $0.id == "weight-week" }
        XCTAssertNotNil(weight)
        XCTAssertEqual(weight?.title, FormaProductCopy.Journey.PersonalRecords.largestWeeklyGainTitle)
        XCTAssertEqual(weight?.value, "1.2 kg")
    }

    func testMostConsistentMonth() {
        let novemberLogs = (0..<12).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80)
        }
        let octoberLogs = (20..<23).map { offset in
            makeLog(daysAgo: offset + 20, calories: 1_800, protein: 80)
        }

        let state = build(maturityLogs: novemberLogs + octoberLogs)

        let month = state.records.first { $0.id == "consistent-month" }
        XCTAssertNotNil(month)
        XCTAssertEqual(month?.value, "November")
        XCTAssertTrue(month?.subtitle?.contains("12") == true)
    }

    func testBestWaterWeek() {
        let logs = (0..<7).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 80,
                waterMl: offset == 0 ? 500 : 2_500
            )
        } + (7..<9).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80, waterMl: 500)
        }

        let state = build(maturityLogs: logs)

        let water = state.records.first { $0.id == "water-week" }
        XCTAssertNotNil(water)
        XCTAssertEqual(water?.value, "6/7 days")
    }

    func testHealthDisconnectedOmitsTrainingRecord() {
        let logs = (0..<6).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }
        let workouts: Set<Date> = [
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: asOf)!),
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: asOf)!)
        ]

        let disconnected = build(
            maturityLogs: logs,
            healthWorkoutDayStarts: workouts,
            isAppleHealthConnected: false
        )
        let connected = build(
            maturityLogs: logs,
            healthWorkoutDayStarts: workouts,
            isAppleHealthConnected: true
        )

        XCTAssertNil(disconnected.records.first { $0.id == "training-week" })
        XCTAssertNotNil(connected.records.first { $0.id == "training-week" })
    }

    func testEarlyRecordLabelForSingleDayStreak() {
        let logs = [0, 2, 4].map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }

        let state = build(maturityLogs: logs)

        let streak = state.records.first { $0.id == "logging-streak" }
        XCTAssertEqual(streak?.value, "1 day")
        XCTAssertEqual(streak?.subtitle, FormaProductCopy.Journey.PersonalRecords.earlyRecord)
        XCTAssertTrue(streak?.isEarlyRecord == true)
    }

    // MARK: - Helpers

    private func build(
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        healthWorkoutDayStarts: Set<Date> = [],
        goalDirection: JourneyGoalDirection = .lose,
        isAppleHealthConnected: Bool = false
    ) -> JourneyPersonalRecordsState {
        JourneyPersonalRecordsBuilder.build(
            JourneyPersonalRecordsBuilder.Input(
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: healthWorkoutDayStarts,
                goalDirection: goalDirection,
                isAppleHealthConnected: isAppleHealthConnected,
                calendar: calendar
            )
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Double,
        protein: Double,
        waterMl: Int = 500
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 120,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_000,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(calories: calories, protein: protein, carbs: 100, fat: 40),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func makeWeight(daysAgo: Int, kg: Double) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }
}
