//
//  JourneyGoalProjectionBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyGoalProjectionBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = TrainingInsightsPreviewData.referenceNow

    func testInsufficientDataFallback() {
        let state = build(
            weights: [
                makeWeight(daysAgo: 2, kg: 88),
                makeWeight(daysAgo: 1, kg: 87.8)
            ],
            baseline: baseline(current: 87.8, goal: 75, direction: .lose)
        )

        XCTAssertTrue(state.isVisible)
        if case .insufficientData(let title, let detail) = state.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.insufficientTitle)
            XCTAssertEqual(detail, FormaProductCopy.Journey.GoalProjection.insufficientDetail)
        } else {
            XCTFail("Expected insufficient data state")
        }
    }

    func testPositiveTrendProjection() {
        let state = build(
            weights: [
                makeWeight(daysAgo: 28, kg: 90),
                makeWeight(daysAgo: 21, kg: 89),
                makeWeight(daysAgo: 14, kg: 88),
                makeWeight(daysAgo: 7, kg: 87),
                makeWeight(daysAgo: 0, kg: 86)
            ],
            baseline: baseline(current: 86, goal: 75, direction: .lose, progress: 36)
        )

        if case .towardGoal(let title, let detail) = state.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.towardGoalTitle)
            XCTAssertTrue(detail.contains("around"))
            XCTAssertTrue(detail.contains("75"))
        } else {
            XCTFail("Expected toward-goal projection, got \(state.status)")
        }
    }

    func testFlatTrendFallback() {
        let state = build(
            weights: [
                makeWeight(daysAgo: 21, kg: 82.0),
                makeWeight(daysAgo: 14, kg: 82.1),
                makeWeight(daysAgo: 7, kg: 81.9),
                makeWeight(daysAgo: 0, kg: 82.0)
            ],
            baseline: baseline(current: 82, goal: 75, direction: .lose, progress: 10)
        )

        if case .flatTrend(let title, let detail) = state.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.flatTrendTitle)
            XCTAssertEqual(detail, FormaProductCopy.Journey.GoalProjection.flatTrendDetail)
        } else {
            XCTFail("Expected flat trend state, got \(state.status)")
        }
    }

    func testAwayFromGoalFallback() {
        let state = build(
            weights: [
                makeWeight(daysAgo: 21, kg: 84),
                makeWeight(daysAgo: 14, kg: 84.5),
                makeWeight(daysAgo: 7, kg: 85),
                makeWeight(daysAgo: 0, kg: 85.8)
            ],
            baseline: baseline(current: 85.8, goal: 75, direction: .lose, progress: 0)
        )

        if case .awayFromGoal(let title, let detail) = state.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.awayFromGoalTitle)
            XCTAssertEqual(detail, FormaProductCopy.Journey.GoalProjection.awayFromGoalDetail)
        } else {
            XCTFail("Expected away-from-goal state, got \(state.status)")
        }
    }

    func testGoalAlreadyReachedState() {
        let state = build(
            weights: [
                makeWeight(daysAgo: 14, kg: 75.2),
                makeWeight(daysAgo: 7, kg: 75.0),
                makeWeight(daysAgo: 0, kg: 75.0)
            ],
            baseline: baseline(current: 75, goal: 75, direction: .lose, progress: 100)
        )

        if case .goalReached(let title, let detail) = state.status {
            XCTAssertEqual(title, FormaProductCopy.Journey.GoalProjection.goalReachedTitle)
            XCTAssertEqual(detail, FormaProductCopy.Journey.GoalProjection.goalReachedDetail)
        } else {
            XCTFail("Expected goal reached state, got \(state.status)")
        }
    }

    func testNoGoalUserIsHidden() {
        let state = build(
            weights: [
                makeWeight(daysAgo: 14, kg: 80),
                makeWeight(daysAgo: 7, kg: 79),
                makeWeight(daysAgo: 0, kg: 78)
            ],
            baseline: baseline(current: 78, goal: nil, direction: .maintain, progress: nil)
        )

        XCTAssertFalse(state.isVisible)
        if case .hidden = state.status {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected hidden state when no goal is set")
        }
    }

    func testMinimumWeightDataRequiresThreeLogsAcrossSevenDays() {
        let shortSpan = [
            makeWeight(daysAgo: 2, kg: 88),
            makeWeight(daysAgo: 1, kg: 87.5),
            makeWeight(daysAgo: 0, kg: 87.2)
        ]
        XCTAssertFalse(JourneyGoalProjectionBuilder.hasMinimumWeightData(weights: shortSpan, calendar: calendar))

        let validSpan = [
            makeWeight(daysAgo: 10, kg: 90),
            makeWeight(daysAgo: 5, kg: 88),
            makeWeight(daysAgo: 0, kg: 86)
        ]
        XCTAssertTrue(JourneyGoalProjectionBuilder.hasMinimumWeightData(weights: validSpan, calendar: calendar))
    }

    func testProjectionCapsAbsurdHorizons() {
        let projection = ProgressProjection(
            currentWeightKg: 100,
            goalWeightKg: 75,
            remainingKg: -25,
            weeklyRateKg: -0.01,
            estimatedWeeksToGoal: 2_500,
            projectedGoalDate: calendar.date(byAdding: .weekOfYear, value: 2_500, to: asOf),
            confidence: .low
        )

        XCTAssertNil(JourneyGoalProjectionBuilder.cappedProjectedDate(projection: projection, asOf: asOf))
    }

    // MARK: - Helpers

    private func build(
        weights: [WeightEntry],
        baseline: JourneyBaseline
    ) -> JourneyGoalProjectionState {
        JourneyGoalProjectionBuilder.build(
            JourneyGoalProjectionBuilder.Input(
                baseline: baseline,
                allWeights: weights,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func baseline(
        current: Double,
        goal: Double?,
        direction: JourneyGoalDirection,
        progress: Double? = nil
    ) -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: current + 4,
            startDate: calendar.date(byAdding: .day, value: -30, to: asOf)!,
            currentWeightKg: current,
            goalWeightKg: goal,
            goalDirection: direction,
            totalChangeKg: -4,
            remainingChangeKg: goal.map { abs(current - $0) },
            progressPercent: progress,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: current + 4,
            chartPoints: [],
            showsWeightChart: true
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
