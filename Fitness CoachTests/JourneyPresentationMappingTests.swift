//
//  JourneyPresentationMappingTests.swift
//  Fitness CoachTests
//
//  Production mapping tests for Journey presentation state, copy conditions, and layout constants.
//

import XCTest
@testable import Fitness_Coach

final class JourneyPresentationMappingTests: XCTestCase {

    private var calendar: Calendar { JourneyPresentationTestSupport.calendar }
    private var asOf: Date { JourneyPresentationTestSupport.asOf }

    // MARK: - 1. Brand-new user

    func testBrandNewUser_HeroWeekOneBuildingFoundationsAndPositiveUnlock() {
        let dashboard = JourneyPreviewData.brandNewUser
        let presentation = dashboard.screenPresentation
        let hero = dashboard.dashboardHero

        XCTAssertEqual(
            hero.weekLabel,
            FormaProductCopy.Journey.Dashboard.Hero.weekLabel(presentation.phase.weekNumber)
        )
        XCTAssertEqual(hero.chapterTitle, FormaProductCopy.Journey.Chapters.title(for: 1))
        XCTAssertEqual(hero.chapterTitle, "Building Foundations")

        XCTAssertTrue(dashboard.showsNextActionSection)
        XCTAssertEqual(
            presentation.unlockDashboard.nextActionCard?.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )

        JourneyPresentationTestSupport.assertNoDuplicateWeeklySections(dashboard)
        JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
        JourneyPresentationTestSupport.assertPrimaryStateIsNotNegativeEmpty(dashboard)

        XCTAssertTrue(presentation.unlockDashboard.showsProminentNextActionCard)
        XCTAssertNotNil(presentation.unlockDashboard.checklist)
        XCTAssertFalse(dashboard.showsMilestonesSection)
    }

    // MARK: - 2. One weigh-in, one workout, zero meals

    func testWeighInAndWorkoutZeroMeals_HeroCelebratesAndNextActionIsFirstMeal() {
        let weighInDaysAgo = 3
        let workoutDaysAgo = 2
        let weighInDate = calendar.date(byAdding: .day, value: -weighInDaysAgo, to: asOf)!
        let workoutDate = calendar.date(byAdding: .day, value: -workoutDaysAgo, to: asOf)!
        let workoutDayStart = calendar.startOfDay(for: workoutDate)

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

        let presentation = dashboard.screenPresentation
        let hero = dashboard.dashboardHero
        let nextAction = presentation.unlockDashboard.nextActionCard

        XCTAssertTrue(
            hero.encouragingSentence.localizedCaseInsensitiveContains("weigh-in")
                || hero.encouragingSentence.localizedCaseInsensitiveContains("workout")
        )
        XCTAssertEqual(presentation.nextBestAction.kind, .logFirstMeal)
        XCTAssertEqual(nextAction?.title, FormaProductCopy.Journey.NextBestAction.logFirstMeal)
        XCTAssertEqual(nextAction?.progressLabel, "0 / 1 meals")

        XCTAssertFalse(presentation.copy.allowsFewMoreMealsCopy)
        let copy = JourneyPresentationTestSupport.joinedUserFacingCopy(from: dashboard)
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("few more meal"))

        JourneyPresentationTestSupport.assertCanonicalDateRangeIsShared(dashboard)

        let weightEvent = dashboard.storyTimeline.displayEvents.first { $0.type == .firstWeightLogged }
        let workoutEvent = dashboard.storyTimeline.displayEvents.first { $0.type == .firstWorkoutLogged }
        XCTAssertNotNil(weightEvent)
        XCTAssertNotNil(workoutEvent)
        XCTAssertEqual(
            calendar.startOfDay(for: weightEvent!.date),
            calendar.startOfDay(for: weighInDate)
        )
        XCTAssertEqual(
            calendar.startOfDay(for: workoutEvent!.date),
            workoutDayStart
        )

        JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
    }

    // MARK: - 3. Meals logged but insufficient meal days

    func testInsufficientMealDays_UsesFewMoreMealsAndBuildingNutrition() {
        let logs = (0..<2).map {
            WeeklyProgressFixtures.makeLog(daysAgo: $0, calories: 1_800)
        }

        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(maturityLogs: logs)
        )
        let presentation = dashboard.screenPresentation

        XCTAssertTrue(presentation.copy.allowsFewMoreMealsCopy)
        XCTAssertEqual(presentation.nextBestAction.kind, .logMealsConsistently)
        XCTAssertEqual(
            presentation.nextBestAction.title,
            FormaProductCopy.Journey.NextBestAction.logMealsConsistently
        )

        let nutritionRow = dashboard.progressSection.rows.first { $0.id == "nutrition" }
        XCTAssertNotNil(nutritionRow)
        XCTAssertEqual(nutritionRow?.value, FormaProductCopy.Journey.Dashboard.Progress.building)
        XCTAssertEqual(nutritionRow?.status, .building)

        let maintenanceValue = dashboard.unifiedWeeklyReview.maintenanceBlock?.title
            ?? dashboard.progressSection.rows.first { $0.id == "nutrition" }?.value
        XCTAssertFalse(maintenanceValue?.localizedCaseInsensitiveContains("ready") == true)

        JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
    }

    // MARK: - 4. Enough meals but insufficient weigh-ins

    func testEnoughMealsInsufficientWeighIns_PrioritizesWeightLogging() {
        let logs = (0..<5).map {
            WeeklyProgressFixtures.makeLog(daysAgo: $0, calories: 1_800)
        }

        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(
                maturityLogs: logs,
                allWeights: [WeeklyProgressFixtures.makeWeight(daysAgo: 0, kg: 80)]
            )
        )
        let presentation = dashboard.screenPresentation

        XCTAssertEqual(presentation.nextBestAction.kind, .logWeightMoreOften)
        XCTAssertEqual(
            presentation.unlockDashboard.nextActionCard?.title,
            FormaProductCopy.Journey.NextBestAction.logWeightMoreOften
        )

        let weightRow = dashboard.progressSection.rows.first { $0.id == "weight-trend" }
        XCTAssertNotNil(weightRow)
        XCTAssertEqual(weightRow?.value, FormaProductCopy.Journey.Dashboard.Progress.building)

        let copy = JourneyPresentationTestSupport.joinedUserFacingCopy(from: dashboard)
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("log your first meal"))
        XCTAssertNotEqual(
            presentation.nextBestAction.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )

        JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
    }

    // MARK: - 5. Enough data

    func testEnoughData_UnlocksWeeklyReviewAndHidesProminentLockedCards() {
        let dashboard = JourneyPreviewData.strongMomentum
        let presentation = dashboard.screenPresentation
        let unified = dashboard.unifiedWeeklyReview

        XCTAssertFalse(presentation.unlockDashboard.showsProminentNextActionCard)
        XCTAssertNil(presentation.unlockDashboard.checklist)
        XCTAssertFalse(dashboard.showsNextActionSection)

        XCTAssertTrue(presentation.unlocks.weeklyReview)
        XCTAssertFalse(unified.isInsufficientData)

        let allowedTitles = [
            FormaProductCopy.Journey.ThisWeek.weeklyReviewReady,
            FormaProductCopy.Journey.ThisWeek.buildingConsistency
        ]
        XCTAssertTrue(allowedTitles.contains(unified.cardStateTitle))

        XCTAssertNotEqual(
            unified.confidenceLabel,
            FormaProductCopy.Journey.WeeklyConfidence.building
        )

        let nutritionRow = dashboard.progressSection.rows.first { $0.id == "nutrition" }
        XCTAssertNotEqual(nutritionRow?.value, FormaProductCopy.Journey.Dashboard.Progress.notStarted)

        JourneyPresentationTestSupport.assertCanonicalDateRangeIsShared(dashboard)
        JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
    }

    func testEnoughDataBuiltDeterministically_ReachesWeeklyReviewThresholds() {
        let logs = (0..<7).map {
            WeeklyProgressFixtures.makeLog(daysAgo: $0, calories: 1_800)
        }
        let weights = [
            WeeklyProgressFixtures.makeWeight(daysAgo: 6, kg: 82),
            WeeklyProgressFixtures.makeWeight(daysAgo: 3, kg: 81),
            WeeklyProgressFixtures.makeWeight(daysAgo: 0, kg: 80)
        ]

        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(
                maturityLogs: logs,
                allWeights: weights,
                healthWorkoutDayStarts: [calendar.startOfDay(for: asOf)],
                isAppleHealthConnected: true
            )
        )

        XCTAssertTrue(dashboard.screenPresentation.unlocks.weeklyReview)
        XCTAssertGreaterThanOrEqual(
            dashboard.screenPresentation.weekly.stats.mealLoggingDays,
            JourneyThresholds.requiredMealLoggingDays
        )
        XCTAssertGreaterThanOrEqual(
            dashboard.screenPresentation.weekly.stats.weighIns,
            JourneyThresholds.requiredWeighIns
        )
    }

    // MARK: - 6. Streak labeling

    func testStreakLabeling_MealStreakHiddenWhenMealDaysZero() {
        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(
                maturityLogs: [
                    WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0, waterMl: 500)
                ]
            )
        )
        let streaks = dashboard.screenPresentation.streaks

        XCTAssertFalse(streaks.showsMealStreak)
        XCTAssertEqual(streaks.mealLoggingStreakDays, 0)
        XCTAssertTrue(streaks.showsCheckInStreak)
        XCTAssertEqual(streaks.primaryMomentumKind, .checkIn)
        XCTAssertEqual(
            streaks.primaryMomentumLabel,
            FormaProductCopy.Journey.Streaks.checkInStreak(days: streaks.checkInStreakDays)
        )
        XCTAssertTrue(streaks.primaryMomentumLabel.localizedCaseInsensitiveContains("check-in streak"))
    }

    func testStreakLabeling_MealStreakUsesMealWordingWhenMealsLogged() {
        let logs = (0..<3).map {
            WeeklyProgressFixtures.makeLog(daysAgo: $0, calories: 1_800)
        }
        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(maturityLogs: logs)
        )
        let streaks = dashboard.screenPresentation.streaks

        XCTAssertTrue(streaks.showsMealStreak)
        XCTAssertEqual(
            streaks.primaryMomentumLabel,
            FormaProductCopy.Journey.Streaks.mealStreak(days: streaks.mealLoggingStreakDays)
        )
        XCTAssertFalse(streaks.primaryMomentumLabel.localizedCaseInsensitiveContains("logging streak"))
    }

    // MARK: - 7. Date consistency

    func testDateConsistency_WeeklyRangeMatchesAcrossSurfaces() {
        let dashboard = JourneyPreviewData.weekOne
        JourneyPresentationTestSupport.assertCanonicalDateRangeIsShared(dashboard)

        XCTAssertEqual(
            dashboard.screenPresentation.weekly.weekRange.startDate,
            dashboard.weeklyProgressSummary.startDate
        )
        XCTAssertEqual(
            dashboard.screenPresentation.weekly.weekRange.endDate,
            dashboard.weeklyProgressSummary.endDate
        )
    }

    func testDateConsistency_StoryEventsUseSourceDatesNotCurrentDate() {
        let weighInDaysAgo = 5
        let workoutDaysAgo = 4
        let weighInDate = calendar.date(byAdding: .day, value: -weighInDaysAgo, to: asOf)!
        let workoutDate = calendar.date(byAdding: .day, value: -workoutDaysAgo, to: asOf)!
        let workoutDayStart = calendar.startOfDay(for: workoutDate)

        let dashboard = JourneyPresentationTestSupport.buildDashboard(
            JourneyPresentationTestSupport.DashboardInput(
                maturityLogs: [],
                allWeights: [WeeklyProgressFixtures.makeWeight(daysAgo: weighInDaysAgo, kg: 79)],
                healthWorkoutDayStarts: [workoutDayStart],
                isAppleHealthConnected: true
            )
        )

        let todayStart = calendar.startOfDay(for: asOf)
        for event in dashboard.storyTimeline.displayEvents where event.type != .onboardingStarted {
            XCTAssertNotEqual(
                calendar.startOfDay(for: event.date),
                todayStart,
                "Story event '\(event.title)' must not use unrelated current date"
            )
        }

        let weightEvent = dashboard.storyTimeline.displayEvents.first { $0.type == .firstWeightLogged }
        XCTAssertEqual(
            calendar.startOfDay(for: weightEvent!.date),
            calendar.startOfDay(for: weighInDate)
        )
    }

    // MARK: - 8. Forbidden user-facing copy

    func testForbiddenCopy_NotPresentAcrossJourneyPersonas() {
        let personas: [JourneyDashboardState] = [
            JourneyPreviewData.brandNewUser,
            JourneyPreviewData.foodLogsOnly,
            JourneyPreviewData.sparseData,
            JourneyPreviewData.weekOne,
            JourneyPreviewData.strongMomentum,
            JourneyPresentationTestSupport.buildDashboard(
                JourneyPresentationTestSupport.DashboardInput(
                    maturityLogs: [
                        WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0)
                    ],
                    allWeights: [WeeklyProgressFixtures.makeWeight(daysAgo: 0, kg: 80)],
                    healthWorkoutDayStarts: [calendar.startOfDay(for: asOf)],
                    isAppleHealthConnected: true
                )
            )
        ]

        for dashboard in personas {
            JourneyPresentationTestSupport.assertNoForbiddenCopy(in: dashboard)
            JourneyPresentationTestSupport.assertPrimaryStateIsNotNegativeEmpty(dashboard)
        }
    }

    func testForbiddenCopy_NoDuplicatedSentenceFragmentsInPresentationStrings() {
        let dashboard = JourneyPreviewData.weekOne
        let strings = JourneyPresentationTestSupport.userFacingCopy(from: dashboard)

        for text in strings where text.contains(". ") {
            let sentences = text
                .split(separator: ".")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            XCTAssertEqual(
                sentences.count,
                Set(sentences).count,
                "Duplicated sentence fragments in: \(text)"
            )
        }
    }

    // MARK: - 9. Bottom padding / layout

    func testBottomPadding_JourneyScrollInsetExceedsFloatingTabBarHeight() {
        JourneyPresentationTestSupport.assertScrollClearanceExceedsTabBar()
    }

    func testBottomPadding_JourneyUsesDedicatedScrollInsetModifier() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: "/workspace/Fitness Coach/Features/Journey/JourneyView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("formaJourneyScrollInsets()"))
        XCTAssertFalse(
            source.contains(".formaMainTabScrollInsets()"),
            "Journey must use formaJourneyScrollInsets(), not the generic tab inset"
        )
    }
}
