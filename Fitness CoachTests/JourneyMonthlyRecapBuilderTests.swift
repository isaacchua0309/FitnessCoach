//
//  JourneyMonthlyRecapBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyMonthlyRecapBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    // Wednesday, 15 Nov 2023
    private let asOf = Date(timeIntervalSince1970: 1_700_044_800)

    func testRecapHiddenWithInsufficientData() {
        let state = build(monthLogs: [], maturityLogs: [])

        XCTAssertFalse(state.isVisible)
        XCTAssertFalse(state.showsTeaser)
        XCTAssertTrue(state.rows.isEmpty)
    }

    func testRecapShowsTeaserWithPartialData() {
        let logs = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 120, waterMl: 2_000) }

        let state = build(monthLogs: logs, maturityLogs: logs)

        XCTAssertTrue(state.isVisible)
        XCTAssertTrue(state.showsTeaser)
        XCTAssertEqual(
            state.teaserTitle,
            FormaProductCopy.Journey.MonthlyRecap.teaserTitle(monthName: "November")
        )
        XCTAssertEqual(
            state.teaserDetail,
            FormaProductCopy.Journey.MonthlyRecap.teaserDetail
        )
        XCTAssertTrue(state.rows.isEmpty)
        XCTAssertFalse(state.isComplete)
    }

    func testRealMetricsAppearWhenDataExists() {
        let logs = (0..<15).map { offset in
            makeLog(
                daysAgo: offset,
                calories: offset < 12 ? 1_900 : 2_600,
                protein: 140,
                waterMl: offset < 13 ? 2_500 : 500
            )
        }
        let weights = [
            makeWeight(daysAgo: 14, kg: 90),
            makeWeight(daysAgo: 0, kg: 87.6)
        ]

        let state = build(
            monthLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            monthHealthWorkoutCount: 11,
            isAppleHealthConnected: true
        )

        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(state.showsTeaser)
        XCTAssertEqual(state.rows.first { $0.id == "meals" }?.value, "15")
        XCTAssertEqual(state.rows.first { $0.id == "protein" }?.value, "100%")
        XCTAssertEqual(state.rows.first { $0.id == "workouts" }?.value, "11")
        XCTAssertEqual(state.rows.first { $0.id == "weight" }?.value, "-2.4 kg")
        XCTAssertTrue(
            ["Strong month", "Excellent month"].contains(
                state.rows.first { $0.id == "overall" }?.value ?? ""
            )
        )
    }

    func testNoFakeZeroPercentMetrics() {
        let logs = (0..<6).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 60,
                waterMl: 400
            )
        }

        let state = build(monthLogs: logs, maturityLogs: logs)

        XCTAssertTrue(state.isComplete)
        XCTAssertNil(state.rows.first { $0.id == "protein" })
        XCTAssertNil(state.rows.first { $0.id == "water" })
        XCTAssertNotNil(state.rows.first { $0.id == "meals" })
    }

    func testGradeCalculationWorks() {
        let strongLogs = (0..<7).enumerated().map { index, offset in
            makeLog(
                daysAgo: offset,
                calories: index < 5 ? 1_900 : 2_600,
                protein: index < 5 ? 140 : 60,
                waterMl: index < 5 ? 2_500 : 400
            )
        }
        let startingLogs = (0..<5).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 2_600,
                protein: 60,
                waterMl: 400
            )
        }

        let strong = build(monthLogs: strongLogs, maturityLogs: strongLogs)
        let starting = build(monthLogs: startingLogs, maturityLogs: startingLogs)

        XCTAssertEqual(strong.overallGrade, .strong)
        XCTAssertEqual(starting.overallGrade, .starting)
    }

    func testHealthDisconnectedOmitsWorkoutRow() {
        let logs = (0..<6).map { makeLog(daysAgo: $0, calories: 1_800, protein: 140, waterMl: 2_000) }

        let disconnected = build(
            monthLogs: logs,
            maturityLogs: logs,
            monthHealthWorkoutCount: 8,
            isAppleHealthConnected: false
        )
        let connected = build(
            monthLogs: logs,
            maturityLogs: logs,
            monthHealthWorkoutCount: 8,
            isAppleHealthConnected: true
        )

        XCTAssertNil(disconnected.rows.first { $0.id == "workouts" })
        XCTAssertEqual(connected.rows.first { $0.id == "workouts" }?.value, "8")
    }

    func testSectionTitleUsesMonthNameRecap() {
        let logs = (0..<6).map { makeLog(daysAgo: $0, calories: 1_800, protein: 140) }
        let state = build(monthLogs: logs, maturityLogs: logs)

        XCTAssertEqual(
            state.sectionTitle,
            FormaProductCopy.Journey.MonthlyRecap.sectionTitle(monthName: "November")
        )
    }

    func testWeightChangeFormattingUsesSignedKilograms() {
        let logs = (0..<6).map { makeLog(daysAgo: $0, calories: 1_800, protein: 140) }
        let weights = [
            makeWeight(daysAgo: 10, kg: 88),
            makeWeight(daysAgo: 1, kg: 86.5)
        ]

        let state = build(
            monthLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            goalDirection: .lose
        )

        XCTAssertEqual(state.rows.first { $0.id == "weight" }?.value, "-1.5 kg")
    }

    // MARK: - Helpers

    private func build(
        monthLogs: [DailyLog],
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        monthHealthWorkoutCount: Int = 0,
        goalDirection: JourneyGoalDirection = .lose,
        isAppleHealthConnected: Bool = false,
        expectedTrainingDaysPerWeek: Int = 3
    ) -> JourneyMonthlyRecapState {
        JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: monthLogs,
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                monthHealthWorkoutCount: monthHealthWorkoutCount,
                goalDirection: goalDirection,
                isAppleHealthConnected: isAppleHealthConnected,
                expectedTrainingDaysPerWeek: expectedTrainingDaysPerWeek,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double,
        waterMl: Int = 2_000
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
