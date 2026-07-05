//
//  JourneyGoldenScenarioTests.swift
//  Fitness CoachTests
//
//  Golden scenario: Week 1 user with first weigh-in + workout, zero meals.
//

import XCTest
@testable import Fitness_Coach

final class JourneyGoldenScenarioTests: XCTestCase {

    private var calendar: Calendar { JourneyPresentationTestSupport.calendar }
    private var asOf: Date { JourneyPresentationTestSupport.asOf }

    func testWeekOneWeighInWorkoutZeroMeals_MatchesProductGoal() {
        let weighInDaysAgo = 3
        let workoutDaysAgo = 2
        let weighInDate = calendar.date(byAdding: .day, value: -weighInDaysAgo, to: asOf)!
        let workoutDayStart = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -workoutDaysAgo, to: asOf)!
        )

        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(
                maturityLogs: [
                    WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0, waterMl: 500)
                ],
                allWeights: [WeeklyProgressFixtures.makeWeight(daysAgo: weighInDaysAgo, kg: 80)],
                healthWorkoutDayStarts: [workoutDayStart],
                isAppleHealthConnected: true
            )
        )

        let hero = dashboard.dashboardHero
        let nextAction = dashboard.screenPresentation.unlockDashboard.nextActionCard
        let weekly = dashboard.unifiedWeeklyReview

        // Hero
        XCTAssertEqual(hero.weekLabel, "Week 1")
        XCTAssertEqual(hero.chapterTitle, "Building Foundations")
        XCTAssertEqual(
            hero.encouragingSentence,
            FormaProductCopy.Journey.Dashboard.Hero.startedWithFirstWeighInAndWorkout
        )

        // Next achievement
        XCTAssertEqual(
            FormaProductCopy.Journey.Unlock.nextAchievementSection,
            "Next achievement"
        )
        XCTAssertEqual(nextAction?.title, "Log your first meal")
        XCTAssertEqual(nextAction?.progressLabel, "0 / 1 meals")
        XCTAssertEqual(
            nextAction?.detail,
            "Unlock nutrition insights and your first weekly review."
        )

        // This Week
        XCTAssertEqual(weekly.cardStateTitle, "Getting started")
        XCTAssertEqual(
            weekly.cardSummary,
            "You logged your first weigh-in and completed your first workout. Log your first meal to unlock nutrition insights."
        )
        XCTAssertEqual(weekly.confidenceLabel, FormaProductCopy.Journey.WeeklyConfidence.building)

        // Progress
        let nutrition = dashboard.progressSection.rows.first { $0.id == "nutrition" }
        let weightTrend = dashboard.progressSection.rows.first { $0.id == "weight-trend" }
        let training = dashboard.progressSection.rows.first { $0.id == "training" }
        let recovery = dashboard.progressSection.rows.first { $0.id == "recovery" }

        XCTAssertEqual(nutrition?.title, "Nutrition")
        XCTAssertEqual(nutrition?.value, "Not started")
        XCTAssertEqual(weightTrend?.value, "Building")
        XCTAssertEqual(training?.value, "1 session")
        XCTAssertEqual(recovery?.value, "Building")

        // Story (oldest first, Started Forma anchor)
        let storyTitles = dashboard.storyTimeline.displayEvents.map(\.title)
        XCTAssertEqual(storyTitles.first, "Started Forma")
        XCTAssertTrue(storyTitles.contains("Logged first weigh-in"))
        XCTAssertTrue(storyTitles.contains("Completed first workout"))

        // Chapter
        XCTAssertEqual(dashboard.chapter.chapterNumber, 1)
        XCTAssertEqual(dashboard.chapter.chapterTitle, "Building Foundations")
        XCTAssertEqual(dashboard.chapter.nextUnlockLabel, "Next: Creating Consistency")
    }
}
