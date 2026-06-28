//
//  JourneyHabitInsightsBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyHabitInsightsBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }()

    // Wednesday, 15 Nov 2023
    private let asOf = Date(timeIntervalSince1970: 1_700_044_800)

    func testInsufficientDataShowsLockedMessage() {
        let logs = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }

        let state = build(maturityLogs: logs)

        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.lockedMessage, FormaProductCopy.Journey.HabitInsights.lockedBody)
    }

    func testStrongestProteinWhenProteinConsistencyIsHighest() {
        let logs = (0..<12).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 140,
                waterMl: offset % 3 == 0 ? 500 : 2_000
            )
        }

        let state = build(maturityLogs: logs)

        XCTAssertTrue(state.isUnlocked)
        XCTAssertEqual(state.strongestHabitLabel, FormaProductCopy.Journey.HabitInsights.proteinLabel)
        XCTAssertGreaterThanOrEqual(state.strongestScorePercent, 75)
    }

    func testWeakestWeekendLoggingWhenWeekendsAreMissed() {
        let logs = weekdayLogs(count: 12, protein: 140, waterMl: 2_000)

        let state = build(maturityLogs: logs)

        XCTAssertTrue(state.isUnlocked)
        XCTAssertEqual(state.weakestHabitLabel, FormaProductCopy.Journey.HabitInsights.weekendLabel)
        XCTAssertLessThan(state.weakestScorePercent, 60)
        XCTAssertEqual(state.weakestScorePrefix, "Only")
        XCTAssertEqual(
            state.suggestedNextAction,
            FormaProductCopy.Journey.HabitInsights.suggestWeekendLogging
        )
    }

    func testHealthDisconnectedDoesNotTreatTrainingAsFailure() {
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80, waterMl: 500)
        }

        let disconnected = build(
            maturityLogs: logs,
            isAppleHealthConnected: false,
            workoutDates: []
        )
        let connected = build(
            maturityLogs: logs,
            isAppleHealthConnected: true,
            workoutDates: []
        )

        XCTAssertTrue(disconnected.isUnlocked)
        XCTAssertTrue(connected.isUnlocked)
        XCTAssertNotEqual(disconnected.weakestHabitLabel, FormaProductCopy.Journey.HabitInsights.trainingLabel)
        XCTAssertEqual(connected.weakestHabitLabel, FormaProductCopy.Journey.HabitInsights.trainingLabel)
    }

    func testNoShameCopyInUnlockedInsights() {
        let logs = weekdayLogs(count: 12, protein: 140, waterMl: 2_000)
        let state = build(maturityLogs: logs)

        let combined = [
            state.strongestHabitLabel,
            state.strongestQualitative ?? "",
            state.weakestHabitLabel,
            state.suggestedNextAction
        ].joined(separator: " ").lowercased()

        for banned in ["fail", "bad", "poor", "worst", "shame", "terrible", "lazy"] {
            XCTAssertFalse(combined.contains(banned), "Unexpected copy containing '\(banned)'")
        }
    }

    func testStableTieBreakingForStrongestHabit() {
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_000)
        }

        let first = build(maturityLogs: logs)
        let second = build(maturityLogs: logs)

        XCTAssertEqual(first.strongestHabitLabel, second.strongestHabitLabel)
        XCTAssertEqual(first.weakestHabitLabel, second.weakestHabitLabel)
        XCTAssertEqual(first.strongestScorePercent, second.strongestScorePercent)
    }

    func testWeightLoggingNotWeakestEarlyInJourney() {
        let logs = (0..<5).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 80, waterMl: 500)
        }
        let recentProfile = ProfileTestFixtures.sampleProfile
        let state = build(
            maturityLogs: logs,
            profileCreatedDaysAgo: 1
        )

        XCTAssertTrue(state.isUnlocked)
        XCTAssertNotEqual(state.weakestHabitLabel, FormaProductCopy.Journey.HabitInsights.weightLabel)
    }

    // MARK: - Helpers

    private func build(
        maturityLogs: [DailyLog],
        weekWeights: [WeightEntry] = [],
        isAppleHealthConnected: Bool = false,
        workoutDates: Set<Date> = [],
        profileCreatedDaysAgo: Int = 30
    ) -> JourneyHabitInsightsState {
        var profile = ProfileTestFixtures.sampleProfile
        let createdAt = calendar.date(byAdding: .day, value: -profileCreatedDaysAgo, to: asOf) ?? asOf
        profile.createdAt = createdAt
        profile.updatedAt = createdAt

        return JourneyHabitInsightsBuilder.build(
            JourneyHabitInsightsBuilder.Input(
                profile: profile,
                maturityLogs: maturityLogs,
                weekLogs: Array(maturityLogs.prefix(7)),
                weekWeights: weekWeights,
                healthWorkoutDayStarts: workoutDates,
                isAppleHealthConnected: isAppleHealthConnected,
                expectedTrainingDaysPerWeek: 4,
                hasRealWeightEntries: !weekWeights.isEmpty,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func weekdayLogs(count: Int, protein: Double, waterMl: Int) -> [DailyLog] {
        var logs: [DailyLog] = []
        var daysAgo = 0
        while logs.count < count {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf) else { break }
            if !isWeekend(date) {
                logs.append(makeLog(date: date, calories: 1_800, protein: protein, waterMl: waterMl))
            }
            daysAgo += 1
        }
        return logs
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double,
        waterMl: Int = 2_000
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return makeLog(date: date, calories: calories, protein: protein, waterMl: waterMl)
    }

    private func makeLog(
        date: Date,
        calories: Int,
        protein: Double,
        waterMl: Int
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 120,
                fat: 50,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}
