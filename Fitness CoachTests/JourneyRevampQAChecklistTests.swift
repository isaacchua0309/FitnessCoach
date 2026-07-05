//
//  JourneyRevampQAChecklistTests.swift
//  Fitness CoachTests
//
//  Executable QA checklist for the Journey revamp. Each numbered test maps to a
//  product scenario from the revamp sign-off list.
//

import XCTest
@testable import Fitness_Coach

final class JourneyRevampQAChecklistTests: XCTestCase {

    // MARK: - 1. Brand new user

    func testQA01_BrandNewUser_ShowsStartingJourneyWithoutClutter() {
        let dashboard = JourneyPreviewData.brandNewUser
        let sections = JourneyRevampQAChecklistSupport.visibleSections(for: dashboard)

        JourneyRevampQAChecklistSupport.assertNoRemovedClutter()
        JourneyRevampQAChecklistSupport.assertNoShameLanguage(in: dashboard)
        JourneyRevampQAChecklistSupport.assertHeroDoesNotShowZeroKgLost(dashboard.transformation)
        JourneyRevampQAChecklistSupport.assertNoFakeZeroPercentMonthlyRecap(dashboard.monthlyRecap)

        XCTAssertFalse(dashboard.showsStartingEmptyState)
        XCTAssertTrue(dashboard.showsDashboardHeroSection)
        XCTAssertTrue(dashboard.showsNextActionSection)
        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        XCTAssertTrue(dashboard.showsProgressSection)
        XCTAssertTrue(dashboard.showsChapterSection)
        XCTAssertEqual(
            dashboard.screenPresentation.unlockDashboard.nextActionCard?.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )

        XCTAssertTrue(sections.contains(.hero))
        XCTAssertTrue(sections.contains(.nextAction))
        XCTAssertTrue(sections.contains(.weeklyProgress))
        XCTAssertTrue(sections.contains(.progress))
        XCTAssertTrue(sections.contains(.chapters))
        XCTAssertFalse(sections.contains(.highlights))
    }

    // MARK: - 2. Food logs only

    func testQA02_FoodLogsOnly_ShowsWeeklyFoodAndLockedProjection() {
        let dashboard = JourneyPreviewData.foodLogsOnly

        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        XCTAssertTrue(dashboard.weeklyHabit.showsHabitRows)
        XCTAssertGreaterThan(dashboard.weeklyReview.foodLoggedDays, 0)

        let foodHabit = dashboard.weeklyHabit.habits.first { $0.id == "food" }
        XCTAssertNotNil(foodHabit)
        XCTAssertTrue(foodHabit?.showsDayProgress == true)

        XCTAssertTrue(dashboard.progressSection.rows.contains { $0.id == "nutrition" })

        XCTAssertTrue(
            dashboard.storyTimeline.displayEvents.contains { $0.type == .firstMealLogged }
                || dashboard.storyEvents.contains { $0.eventType == .firstMealLogged }
        )
        XCTAssertFalse(dashboard.baseline.hasRealWeightEntries)
    }

    // MARK: - 3. Weight logs but no loss

    func testQA03_WeightLogsNoLoss_ShowsSupportiveFlatProjection() {
        let dashboard = JourneyPreviewData.weightLogsNoLoss

        JourneyRevampQAChecklistSupport.assertNoShameLanguage(in: dashboard)
        JourneyRevampQAChecklistSupport.assertHeroDoesNotShowZeroKgLost(dashboard.transformation)
        XCTAssertNotEqual(dashboard.transformation.variant, .weightLossProgress)

        XCTAssertTrue(dashboard.baseline.hasRealWeightEntries)
        XCTAssertTrue(dashboard.showsGoalProjectionSection)

        switch dashboard.goalProjection.status {
        case .flatTrend, .insufficientData:
            break
        default:
            XCTFail("Expected flat or learning projection, got \(dashboard.goalProjection.status)")
        }
    }

    // MARK: - 4. User losing weight

    func testQA04_WeightLossUser_ShowsTransformationAndMilestones() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertEqual(dashboard.transformation.variant, .weightLossProgress)
        XCTAssertTrue(dashboard.transformation.primaryMessage.localizedCaseInsensitiveContains("lost"))
        JourneyRevampQAChecklistSupport.assertHeroDoesNotShowZeroKgLost(dashboard.transformation)
        XCTAssertTrue(dashboard.transformation.showsProgressBar)

        XCTAssertTrue(dashboard.showsGoalProjectionSection)
        if case .towardGoal = dashboard.goalProjection.status {
            // Expected for strong momentum fixture.
        } else {
            XCTFail("Expected toward-goal projection for weight-loss fixture")
        }

        let unlockedIDs = Set(dashboard.milestones.unlocked.map(\.id))
        XCTAssertTrue(unlockedIDs.contains("first-kg"))

        XCTAssertTrue(
            dashboard.storyTimeline.displayEvents.contains { $0.type == .firstKgTowardGoal }
                || dashboard.storyEvents.contains { $0.eventType == .firstKgTowardGoal }
        )
    }

    // MARK: - 5. User with workouts

    func testQA05_UserWithWorkouts_ShowsTrainingConsistencyAndStory() {
        let dashboard = JourneyPreviewData.healthConnected

        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        XCTAssertGreaterThan(dashboard.weeklyReview.trainingDays, 0)
        XCTAssertTrue(dashboard.weeklyReview.training.showsWorkoutRow)

        let trainingHabit = dashboard.weeklyHabit.habits.first { $0.id == "training" }
        XCTAssertNotNil(trainingHabit)

        XCTAssertTrue(
            dashboard.storyTimeline.displayEvents.contains { $0.type == .firstWorkoutLogged }
                || dashboard.storyEvents.contains { $0.eventType == .firstWorkoutLogged }
                || dashboard.milestones.unlocked.contains { $0.id == "first-workout" }
        )
    }

    // MARK: - 6. Strong consistency

    func testQA06_StrongConsistency_UpgradesMomentumAndChapter() {
        let dashboard = JourneyPreviewData.highlyConsistent

        XCTAssertTrue(dashboard.showsDashboardHeroSection)
        XCTAssertGreaterThan(dashboard.momentum.streakDays, 0)
        XCTAssertTrue(
            dashboard.transformation.variant == .weightLossProgress
                || dashboard.transformation.variant == .strongConsistency
        )

        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        XCTAssertGreaterThanOrEqual(dashboard.weeklyReview.foodLoggedDays, 6)

        let foodHabit = dashboard.weeklyHabit.habits.first { $0.id == "food" }
        XCTAssertNotNil(foodHabit?.streakLabel)

        XCTAssertTrue(dashboard.showsChapterSection)
        XCTAssertGreaterThan(dashboard.chapter.totalXP, 0)
        XCTAssertGreaterThan(dashboard.chapter.progressPercent, 0)
    }

    // MARK: - 7. Small screen layout

    func testQA07_SmallScreenLayout_HasTabClearanceAndWrappingHeadroom() {
        JourneyRevampQAChecklistSupport.assertSmallScreenLayoutContract()

        let dashboard = JourneyPreviewData.brandNewUser
        let longCopyDashboard = JourneyPreviewData.strongMomentum

        for sample in [dashboard, longCopyDashboard] {
            XCTAssertFalse(sample.transformation.primaryMessage.isEmpty)
            XCTAssertFalse(sample.transformation.body.isEmpty)
            XCTAssertFalse(sample.milestone.rewardCopy.isEmpty)
        }

        XCTAssertGreaterThan(
            FormaMainTabLayout.scrollBottomInset,
            FormaTokens.Layout.floatingTabBarHeight
        )
    }

    // MARK: - 8. Accessibility

    func testQA08_Accessibility_ImportantProgressIsAnnounced() {
        let samples = [
            JourneyPreviewData.brandNewUser,
            JourneyPreviewData.foodLogsOnly,
            JourneyPreviewData.strongMomentum,
            JourneyPreviewData.highlyConsistent,
        ]

        for dashboard in samples {
            JourneyRevampQAChecklistSupport.assertAccessibilityContract(for: dashboard)
            if dashboard.showsWeeklyProgressSection {
                JourneyRevampQAChecklistSupport.assertWeeklyProgressAccessibility(for: dashboard)
            }
        }

        let weightLoss = JourneyPreviewData.strongMomentum
        XCTAssertFalse(weightLoss.milestone.accessibilitySummary.isEmpty)
        XCTAssertTrue(
            weightLoss.milestone.accessibilitySummary.localizedCaseInsensitiveContains("percent")
                || weightLoss.milestone.progressText.contains("/")
        )

        XCTAssertEqual(
            FormaProductCopy.Journey.StartingEmptyState.action,
            "Go to Today"
        )
    }

    func testQA09_WeeklyProgressSection_ShowsUnifiedReviewForStrongMomentum() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        JourneyRevampQAChecklistSupport.assertWeeklyProgressAccessibility(for: dashboard)

        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)
        XCTAssertTrue(unified.isReady)
        XCTAssertFalse(unified.headline.isEmpty)
        XCTAssertEqual(unified.id, dashboard.weeklyProgressSummary.id)
    }

    func testQA10_WeeklyProgress_DoesNotDuplicateLegacyWeeklyReview() {
        let dashboard = JourneyPreviewData.strongMomentum
        let sections = JourneyRevampQAChecklistSupport.visibleSections(for: dashboard)

        XCTAssertTrue(sections.contains(.weeklyProgress))
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsLegacyWeeklyReviewSection(
                dashboard: dashboard,
                showsWeeklyProgressHero: true,
                isHealthIntelligenceUIEnabled: false,
                healthIntelligenceSectionState: nil
            )
        )
    }

    // MARK: - Layout regression guard

    func testQA_LayoutOrder_MatchesRevampSpec() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder.first, .hero)
        XCTAssertEqual(JourneyProductLayout.sectionOrder.last, .chapters)
        JourneyRevampQAChecklistSupport.assertNoRemovedClutter()
        JourneyRevampQAChecklistSupport.assertNoBannedLiveCopy(in: JourneyPreviewData.strongMomentum)
    }
}
