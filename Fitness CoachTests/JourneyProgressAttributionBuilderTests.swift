//
//  JourneyProgressAttributionBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyProgressAttributionBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    func testCalorieAdherencePrimaryReasonWhenAlignedWithLoseGoal() {
        let adhering = (0..<19).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 120)
        }
        let nonAdhering = (19..<23).map { offset in
            makeLog(daysAgo: offset, calories: 2_500, protein: 120)
        }
        let logs = adhering + nonAdhering

        let state = build(
            currentPeriodLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            goalDirection: .lose,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 84,
                changeKg: -1.2,
                direction: .decreasing,
                hasSuddenSpike: false
            )
        )

        XCTAssertEqual(
            state.primaryReasonTitle,
            FormaProductCopy.Journey.WhyProgress.calorieLikelyHelpedTitle
        )
        XCTAssertEqual(
            state.primaryReasonDetail,
            FormaProductCopy.Journey.WhyProgress.stayedWithinCalories(achieved: 19, eligible: 23)
        )
    }

    func testProteinImprovementCanBePrimaryReason() {
        let previousWeek = (0..<5).map { offset in
            makeLog(daysAgo: offset + 7, calories: 2_500, protein: 80)
        }
        let thisWeek = (0..<7).map { offset in
            makeLog(daysAgo: offset, calories: 2_500, protein: 140)
        }
        let maturity = thisWeek + previousWeek

        let state = build(
            currentPeriodLogs: maturity,
            weekLogs: thisWeek,
            previousWeekLogs: previousWeek,
            goalDirection: .lose,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 90,
                changeKg: 0,
                direction: .stable,
                hasSuddenSpike: false
            )
        )

        XCTAssertEqual(
            state.primaryReasonTitle,
            FormaProductCopy.Journey.WhyProgress.proteinAnchorTitle
        )
        XCTAssertTrue(state.primaryReasonDetail.localizedCaseInsensitiveContains("protein"))
    }

    func testLoggingConsistencyPrimaryReason() {
        let previousWeek = (0..<3).map { offset in
            makeLog(daysAgo: offset + 7, calories: 2_500, protein: 80)
        }
        let thisWeek = (0..<7).map { offset in
            makeLog(daysAgo: offset, calories: 2_500, protein: 80)
        }

        let state = build(
            currentPeriodLogs: thisWeek + previousWeek,
            weekLogs: thisWeek,
            previousWeekLogs: previousWeek,
            goalDirection: .maintain,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 72,
                changeKg: 0,
                direction: .stable,
                hasSuddenSpike: false
            )
        )

        XCTAssertEqual(
            state.primaryReasonTitle,
            FormaProductCopy.Journey.WhyProgress.loggingControlTitle
        )
        XCTAssertEqual(
            state.primaryReasonDetail,
            FormaProductCopy.Journey.WhyProgress.loggedFoodDaysThisWeek(7)
        )
    }

    func testInsufficientDataFallback() {
        let logs = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }

        let state = build(currentPeriodLogs: logs, weekLogs: logs)

        XCTAssertEqual(state, .insufficientData)
        XCTAssertEqual(state.confidence, .low)
    }

    func testNoOverclaimingLanguage() {
        let logs = (0..<12).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140)
        }
        let state = build(
            currentPeriodLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            goalDirection: .lose,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 84,
                changeKg: -1.0,
                direction: .decreasing,
                hasSuddenSpike: false
            )
        )

        let combined = ([state.primaryReasonTitle, state.primaryReasonDetail] + state.supportingReasons)
            .joined(separator: " ")
            .lowercased()

        for banned in ["proved", "caused", "guaranteed", "definitely", "medical", "cure", "certain"] {
            XCTAssertFalse(combined.contains(banned), "Unexpected overclaiming word '\(banned)'")
        }
        if state.primaryReasonTitle.contains("likely") {
            XCTAssertTrue(state.primaryReasonTitle.contains("likely helped"))
        }
    }

    func testGainGoalUsesGainWeightTrendCopy() {
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 2_200, protein: 140)
        }
        let state = build(
            currentPeriodLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            goalDirection: .gain,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 68,
                changeKg: 0.8,
                direction: .increasing,
                hasSuddenSpike: false
            )
        )

        let messages = [state.primaryReasonDetail] + state.supportingReasons
        XCTAssertTrue(
            messages.contains {
                $0.contains("gain goal") || $0.contains("calories") || $0.contains("logged food")
            }
        )
    }

    func testMaintainGoalDoesNotUseLoseLanguage() {
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 120)
        }
        let state = build(
            currentPeriodLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            goalDirection: .maintain,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 72,
                changeKg: 0.1,
                direction: .stable,
                hasSuddenSpike: false
            )
        )

        let combined = ([state.primaryReasonTitle, state.primaryReasonDetail] + state.supportingReasons)
            .joined(separator: " ")
            .lowercased()
        XCTAssertFalse(combined.contains("lost"))
        XCTAssertFalse(combined.contains("fat loss"))
    }

    func testSupportingReasonsAreLimitedToThree() {
        let previousWeek = (0..<4).map { offset in
            makeLog(daysAgo: offset + 7, calories: 1_800, protein: 80, waterMl: 500)
        }
        let thisWeek = (0..<7).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_000)
        }

        let state = build(
            currentPeriodLogs: thisWeek + previousWeek,
            weekLogs: thisWeek,
            previousWeekLogs: previousWeek,
            goalDirection: .lose,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 84,
                changeKg: -1.0,
                direction: .decreasing,
                hasSuddenSpike: false
            ),
            weeklyTrainingDays: 4,
            previousWeekTrainingDays: 1,
            isAppleHealthConnected: true
        )

        XCTAssertLessThanOrEqual(state.supportingReasons.count, 3)
    }

    // MARK: - Helpers

    private func build(
        currentPeriodLogs: [DailyLog],
        weekLogs: [DailyLog],
        previousWeekLogs: [DailyLog] = [],
        goalDirection: JourneyGoalDirection = .lose,
        weightSummary: ProgressWeightSummary = ProgressWeightSummary(
            latestWeightKg: 90,
            changeKg: 0,
            direction: .insufficientData,
            hasSuddenSpike: false
        ),
        weeklyTrainingDays: Int = 0,
        previousWeekTrainingDays: Int = 0,
        isAppleHealthConnected: Bool = false
    ) -> JourneyProgressAttributionState {
        JourneyProgressAttributionBuilder.build(
            JourneyProgressAttributionBuilder.Input(
                currentPeriodLogs: currentPeriodLogs,
                previousPeriodLogs: previousWeekLogs,
                weekLogs: weekLogs,
                previousWeekLogs: previousWeekLogs,
                weightSummary: weightSummary,
                goalDirection: goalDirection,
                weeklyTrainingDays: weeklyTrainingDays,
                previousWeekTrainingDays: previousWeekTrainingDays,
                isAppleHealthConnected: isAppleHealthConnected,
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
