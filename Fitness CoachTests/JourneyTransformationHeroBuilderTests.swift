//
//  JourneyTransformationHeroBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyTransformationHeroBuilderTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let asOf = ProfileTestFixtures.referenceDate

    // MARK: - Headlines

    func testLoseGoalHeadline() {
        let state = build(
            baseline: baseline(
                start: 90,
                current: 86,
                goal: 75,
                direction: .lose,
                progress: 27
            )
        )

        XCTAssertEqual(state.headlineCopy, "You've lost")
        XCTAssertEqual(state.changeValueCopy, "4 kg")
    }

    func testGainGoalHeadline() {
        let state = build(
            baseline: baseline(
                start: 60,
                current: 63.8,
                goal: 70,
                direction: .gain,
                progress: 38
            )
        )

        XCTAssertEqual(state.headlineCopy, "You've gained")
        XCTAssertEqual(state.changeValueCopy, "3.8 kg")
    }

    func testMaintainGoalHeadline() {
        let state = build(
            baseline: baseline(
                start: 72,
                current: 72.4,
                goal: 72,
                direction: .maintain,
                progress: nil
            )
        )

        XCTAssertEqual(state.headlineCopy, "You're maintaining")
        XCTAssertEqual(state.changeValueCopy, "0.4 kg")
    }

    // MARK: - Progress

    func testProgressLabelFormatting() {
        let state = build(
            baseline: baseline(
                start: 90,
                current: 86.2,
                goal: 75,
                direction: .lose,
                progress: 42.4
            )
        )

        XCTAssertEqual(state.progressLabel, "42% complete")
        XCTAssertEqual(state.progressBarAccessibilityValue, "42 percent complete")
    }

    func testProgressLabelNeverNegative() {
        let state = build(
            baseline: baseline(
                start: 80,
                current: 82,
                goal: 70,
                direction: .lose,
                progress: 0
            )
        )

        XCTAssertEqual(state.progressLabel, "0% complete")
    }

    // MARK: - Forecast

    func testForecastUsesMonthWhenAvailable() {
        let state = build(
            baseline: baseline(
                start: 90,
                current: 86,
                goal: 75,
                direction: .lose,
                progress: 27,
                completionMonth: "October"
            )
        )

        XCTAssertEqual(
            state.paceForecastText,
            "At this pace you'll reach your goal in October."
        )
    }

    func testForecastFallbackWhenTrendInsufficient() {
        let state = build(
            baseline: baseline(
                start: 82,
                current: 82,
                goal: 74,
                direction: .lose,
                progress: 0,
                usesSynthetic: true
            ),
            loggedDays: 2
        )

        XCTAssertEqual(
            state.paceForecastText,
            "Keep logging and Forma will forecast your pace."
        )
    }

    // MARK: - Synthetic baseline

    func testSyntheticBaselineStartedFootnote() {
        let state = build(
            baseline: baseline(
                start: 82,
                current: 82,
                goal: 74,
                direction: .lose,
                progress: 0,
                usesSynthetic: true
            )
        )

        XCTAssertTrue(state.usesSyntheticBaseline)
        XCTAssertEqual(state.startedFootnote, "Onboarding")
        XCTAssertTrue(state.accessibilitySummary.contains("onboarding"))
    }

    func testLoggedBaselineOmitsStartedFootnote() {
        let state = build(
            baseline: baseline(
                start: 90,
                current: 86,
                goal: 75,
                direction: .lose,
                progress: 27,
                usesSynthetic: false
            )
        )

        XCTAssertFalse(state.usesSyntheticBaseline)
        XCTAssertNil(state.startedFootnote)
    }

    // MARK: - Emotional status

    func testNewUserEmotionalStatus() {
        let state = build(
            baseline: baseline(
                start: 82,
                current: 82,
                goal: 74,
                direction: .lose,
                progress: 0,
                usesSynthetic: true
            ),
            loggedDays: 2
        )

        XCTAssertEqual(state.emotionalStatusLabel, "Laying the foundation")
    }

    func testNearGoalEmotionalStatus() {
        let state = build(
            baseline: baseline(
                start: 90,
                current: 76,
                goal: 75,
                direction: .lose,
                progress: 93
            ),
            loggedDays: 30
        )

        XCTAssertEqual(state.emotionalStatusLabel, "Closing in")
    }

    // MARK: - Streak

    func testStreakChipHiddenWhenZero() {
        let state = build(loggingStreak: 0)
        XCTAssertFalse(state.streakChip.isVisible)
    }

    func testStreakChipFormatting() {
        let state = build(loggingStreak: 7)
        XCTAssertTrue(state.streakChip.isVisible)
        XCTAssertEqual(state.streakChip.label, "7-day logging streak")
    }

    // MARK: - Helpers

    private func build(
        baseline: JourneyBaseline? = nil,
        loggedDays: Int = 14,
        loggingStreak: Int = 3,
        weightTrendDirection: WeightTrendDirection = .decreasing
    ) -> JourneyTransformationHeroState {
        let heroStreakChip: JourneyStreakChipState = loggingStreak > 0
            ? JourneyStreakChipState(
                isVisible: true,
                days: loggingStreak,
                label: FormaProductCopy.Journey.Streaks.loggingStreak(days: loggingStreak)
            )
            : .hidden

        return JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: baseline ?? self.baseline(
                    start: 90,
                    current: 86,
                    goal: 75,
                    direction: .lose,
                    progress: 27
                ),
                loggedDays: loggedDays,
                heroStreakChip: heroStreakChip,
                weightTrendDirection: weightTrendDirection,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func baseline(
        start: Double,
        current: Double,
        goal: Double,
        direction: JourneyGoalDirection,
        progress: Double?,
        completionMonth: String? = nil,
        usesSynthetic: Bool = false
    ) -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: start,
            startDate: calendar.date(byAdding: .day, value: -21, to: asOf) ?? asOf,
            currentWeightKg: current,
            goalWeightKg: goal,
            goalDirection: direction,
            totalChangeKg: current - start,
            remainingChangeKg: abs(current - goal),
            progressPercent: progress,
            estimatedCompletionDate: completionMonth == nil
                ? nil
                : calendar.date(byAdding: .month, value: 2, to: asOf),
            estimatedCompletionMonthLabel: completionMonth,
            hasRealWeightEntries: !usesSynthetic,
            usesSyntheticBaselinePoint: usesSynthetic,
            onboardingBaselineWeightKg: start,
            chartPoints: [],
            showsWeightChart: true
        )
    }
}
