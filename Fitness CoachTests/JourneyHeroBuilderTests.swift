//
//  JourneyHeroBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyHeroBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = TrainingInsightsPreviewData.referenceNow

    func testNewUserDoesNotSeeZeroKgLost() {
        let hero = buildHero(
            loggedDays: 0,
            baseline: baseline(start: 82, current: 82, goal: 74, direction: .lose, progress: 0)
        )

        XCTAssertEqual(hero.variant, .newUser)
        XCTAssertEqual(hero.title, FormaProductCopy.Journey.Hero.newUserTitle)
        XCTAssertEqual(hero.primaryMessage, FormaProductCopy.Journey.Hero.newUserPrimary)
        XCTAssertFalse(hero.primaryMessage.localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(hero.primaryMessage.contains("0 kg"))
        XCTAssertFalse(hero.showsProgressBar)
    }

    func testWeightLossUserSeesKgLost() {
        let hero = buildHero(
            loggedDays: 20,
            streakDays: 3,
            baseline: baseline(start: 90, current: 86.2, goal: 75, direction: .lose, progress: 42)
        )

        XCTAssertEqual(hero.variant, .weightLossProgress)
        XCTAssertTrue(hero.primaryMessage.localizedCaseInsensitiveContains("lost"))
        XCTAssertTrue(hero.primaryMessage.contains("kg"))
        XCTAssertTrue(hero.showsProgressBar)
        XCTAssertTrue(hero.body.contains("%"))
    }

    func testNoGoalUserGetsSafeFallback() {
        let hero = buildHero(
            loggedDays: 4,
            baseline: baseline(start: 80, current: 79.5, goal: nil, direction: .maintain, progress: nil)
        )

        XCTAssertEqual(hero.variant, .noGoalFallback)
        XCTAssertEqual(hero.title, FormaProductCopy.Journey.Hero.noGoalTitle)
        XCTAssertEqual(hero.primaryMessage, FormaProductCopy.Journey.Hero.noGoalPrimary)
        XCTAssertFalse(hero.primaryMessage.localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(hero.showsProgressBar)
    }

    func testGainingWeightUserDoesNotGetShamed() {
        let hero = buildHero(
            loggedDays: 5,
            streakDays: 2,
            baseline: baseline(start: 60, current: 60.2, goal: 70, direction: .gain, progress: 2)
        )

        XCTAssertNotEqual(hero.variant, .weightLossProgress)
        XCTAssertFalse(hero.primaryMessage.localizedCaseInsensitiveContains("0 kg"))
        XCTAssertFalse(hero.primaryMessage.localizedCaseInsensitiveContains("lost"))
    }

    func testStrongConsistencyUserSeesDaysShowingUp() {
        let hero = buildHero(
            loggedDays: 14,
            streakDays: 9,
            baseline: baseline(start: 88, current: 87.8, goal: 75, direction: .lose, progress: 2)
        )

        XCTAssertEqual(hero.variant, .strongConsistency)
        XCTAssertEqual(hero.title, FormaProductCopy.Journey.Hero.strongConsistencyTitle)
        XCTAssertTrue(hero.primaryMessage.contains("showing up"))
    }

    func testEarlyHabitUserSeesBuildingMomentum() {
        let hero = buildHero(
            loggedDays: 4,
            streakDays: 3,
            baseline: baseline(start: 89, current: 88.3, goal: 75, direction: .lose, progress: 5)
        )

        XCTAssertEqual(hero.variant, .earlyHabits)
        XCTAssertEqual(hero.title, FormaProductCopy.Journey.Hero.earlyHabitsTitle)
        XCTAssertTrue(hero.primaryMessage.hasPrefix("Week "))
    }

    func testPreviewBrandNewUserHeroMatchesSpec() {
        let hero = JourneyPreviewData.brandNewUser.transformation

        XCTAssertEqual(hero.variant, .newUser)
        XCTAssertFalse(hero.primaryMessage.contains("0 kg"))
    }

    func testPreviewStrongMomentumShowsWeightLossPrimary() {
        let hero = JourneyPreviewData.strongMomentum.transformation

        XCTAssertEqual(hero.variant, .weightLossProgress)
        XCTAssertTrue(hero.primaryMessage.localizedCaseInsensitiveContains("lost"))
    }

    // MARK: - Helpers

    private func buildHero(
        loggedDays: Int,
        streakDays: Int = 0,
        baseline: JourneyBaseline
    ) -> JourneyTransformationState {
        let streaks = JourneyStreakState(
            currentLoggingStreakDays: streakDays,
            longestLoggingStreakDays: max(streakDays, 1),
            currentProteinStreakDays: 0,
            currentWaterStreakDays: 0,
            currentTrainingStreakWeeks: nil,
            isTodayLogged: streakDays > 0,
            heroStreakChip: .hidden,
            weeklyConsistencyHeadline: "",
            weeklyConsistencyDetail: nil,
            keepStreakAliveCopy: nil
        )

        return JourneyHeroBuilder.build(
            JourneyHeroBuilder.Input(
                baseline: baseline,
                loggedDays: loggedDays,
                journeyStreaks: streaks,
                hasProfile: true,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func baseline(
        start: Double,
        current: Double,
        goal: Double?,
        direction: JourneyGoalDirection,
        progress: Double?
    ) -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: start,
            startDate: calendar.date(byAdding: .day, value: -20, to: asOf)!,
            currentWeightKg: current,
            goalWeightKg: goal,
            goalDirection: direction,
            totalChangeKg: current - start,
            remainingChangeKg: goal.map { abs(current - $0) },
            progressPercent: progress,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: start,
            chartPoints: [],
            showsWeightChart: true
        )
    }
}
