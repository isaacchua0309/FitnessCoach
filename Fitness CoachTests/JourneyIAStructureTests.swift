//
//  JourneyIAStructureTests.swift
//  Fitness CoachTests
//
//  Forma — Journey dashboard information architecture tests.
//

import XCTest
@testable import Fitness_Coach

final class JourneyIAStructureTests: XCTestCase {

    func testCanonicalSectionOrderMatchesDashboardIA() {
        XCTAssertEqual(JourneyProductLayout.sectionOrder, [
            .hero,
            .nextAction,
            .weeklyProgress,
            .progress,
            .highlights,
            .storyTimeline,
            .chapters
        ])
    }

    func testBrandNewUserShowsStoryAndChapterProgress() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.showsStoryTimelineSection)
        XCTAssertTrue(
            dashboard.storyTimeline.displayEvents.contains { $0.type == .onboardingStarted }
        )
        XCTAssertEqual(dashboard.chapter.progressItems.count, 6)
        XCTAssertEqual(
            dashboard.chapter.nextUnlockLabel,
            FormaProductCopy.Journey.Chapters.nextUnlock(
                FormaProductCopy.Journey.Chapters.title(for: 2)
            )
        )
    }

    func testBrandNewUserShowsHeroNextActionThisWeekAndProgress() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.showsDashboardHeroSection)
        XCTAssertTrue(dashboard.showsNextActionSection)
        XCTAssertTrue(dashboard.showsWeeklyProgressSection)
        XCTAssertTrue(dashboard.showsProgressSection)
        XCTAssertFalse(dashboard.showsStartingEmptyState)
        XCTAssertEqual(
            dashboard.dashboardHero.weekLabel,
            FormaProductCopy.Journey.Dashboard.Hero.weekLabel(
                dashboard.screenPresentation.phase.weekNumber
            )
        )
    }

    func testStrongMomentumShowsHighlightsWhenHealthIntelligenceLoaded() {
        let dashboard = JourneyPreviewData.strongMomentum
        let hi = JourneyHealthIntelligencePreviewData.strongWeek

        XCTAssertTrue(
            JourneyDashboardCompositionPolicy.showsHighlightsSection(
                isUIEnabled: true,
                sectionState: hi
            )
        )
        XCTAssertFalse(dashboard.showsNextActionSection)
        XCTAssertTrue(dashboard.showsChapterSection)
    }

    func testProgressSectionUsesCompactRows() {
        let dashboard = JourneyPreviewData.weekOne

        XCTAssertFalse(dashboard.progressSection.rows.isEmpty)
        XCTAssertTrue(dashboard.progressSection.rows.contains { $0.id == "nutrition" })
        XCTAssertTrue(dashboard.progressSection.rows.contains { $0.id == "training" })
    }

    func testHeroUsesActualHighlightsWhenAvailable() {
        let presentation = JourneyScreenPresentationBuilder.build(
            makePresentationInput(
                maturityLogs: [
                    WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0)
                ],
                weights: [WeeklyProgressFixtures.makeWeight(daysAgo: 0, kg: 80)],
                healthWorkoutDayStarts: [WeeklyProgressFixtures.calendar.startOfDay(for: WeeklyProgressFixtures.asOf)]
            )
        )
        let hero = JourneyDashboardHeroBuilder.build(
            JourneyDashboardHeroBuilder.Input(
                screenPresentation: presentation,
                weeklySummary: JourneyDashboardBuilder.weeklyProgressSummary(
                    context: makeContext(
                        maturityLogs: [WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0)],
                        weights: [WeeklyProgressFixtures.makeWeight(daysAgo: 0, kg: 80)],
                        healthWorkoutDayStarts: [WeeklyProgressFixtures.calendar.startOfDay(for: WeeklyProgressFixtures.asOf)]
                    )
                ),
                hasProfile: true
            )
        )

        XCTAssertTrue(hero.encouragingSentence.localizedCaseInsensitiveContains("weigh-in"))
        XCTAssertTrue(hero.encouragingSentence.localizedCaseInsensitiveContains("workout"))
    }

    // MARK: - Helpers

    private func makePresentationInput(
        maturityLogs: [DailyLog],
        weights: [WeightEntry],
        healthWorkoutDayStarts: Set<Date>
    ) -> JourneyScreenPresentationBuilder.Input {
        let context = makeContext(
            maturityLogs: maturityLogs,
            weights: weights,
            healthWorkoutDayStarts: healthWorkoutDayStarts
        )
        let summary = JourneyDashboardBuilder.weeklyProgressSummary(context: context)
        return JourneyScreenPresentationBuilder.Input(
            context: context,
            weeklyProgressSummary: summary,
            chapter: JourneyChapterBuilder.build(
                JourneyChapterBuilder.Input(
                    profile: ProfileTestFixtures.sampleProfile,
                    maturityLogs: maturityLogs,
                    allWeights: weights,
                    healthWorkoutDayStarts: healthWorkoutDayStarts,
                    isAppleHealthConnected: !healthWorkoutDayStarts.isEmpty,
                    unlockedMilestoneCount: 0,
                    checkInStreakDays: 0,
                    weeklyReviewUnlocked: false,
                    calendar: WeeklyProgressFixtures.calendar
                )
            ),
            storyEvents: [],
            insight: JourneyInsightState(
                isVisible: true,
                sectionTitle: FormaProductCopy.Journey.PersonalizedInsights.sectionTitle,
                showsLearningState: true,
                learningTitle: FormaProductCopy.Journey.PersonalizedInsights.learningTitle,
                learningDetail: FormaProductCopy.Journey.PersonalizedInsights.learningDetail,
                insights: [],
                accessibilitySummary: ""
            ),
            goalProjection: JourneyGoalProjectionBuilder.build(
                JourneyGoalProjectionBuilder.Input(
                    baseline: context.baseline,
                    allWeights: weights,
                    asOf: WeeklyProgressFixtures.asOf,
                    calendar: WeeklyProgressFixtures.calendar
                )
            ),
            freshnessInput: nil
        )
    }

    private func makeContext(
        maturityLogs: [DailyLog],
        weights: [WeightEntry],
        healthWorkoutDayStarts: Set<Date>
    ) -> JourneyDashboardBuilder.Context {
        let baseline = JourneyBaseline(
            startWeightKg: 80,
            startDate: WeeklyProgressFixtures.calendar.date(byAdding: .day, value: -7, to: WeeklyProgressFixtures.asOf)!,
            currentWeightKg: 80,
            goalWeightKg: 72,
            goalDirection: .lose,
            totalChangeKg: 0,
            remainingChangeKg: 8,
            progressPercent: 0,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: !weights.isEmpty,
            usesSyntheticBaselinePoint: weights.isEmpty,
            onboardingBaselineWeightKg: 80,
            chartPoints: [],
            showsWeightChart: true
        )
        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: Array(healthWorkoutDayStarts),
            asOf: WeeklyProgressFixtures.asOf,
            calendar: WeeklyProgressFixtures.calendar
        )
        return JourneyDashboardBuilder.Context(
            profile: ProfileTestFixtures.sampleProfile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: maturityLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: weights,
            weekWeights: weights,
            journeyStreaks: JourneyStreakBuilder.build(
                JourneyStreakBuilder.Input(
                    streakSummary: streakSummary,
                    maturityLogs: maturityLogs,
                    workoutDates: Array(healthWorkoutDayStarts),
                    isAppleHealthConnected: !healthWorkoutDayStarts.isEmpty,
                    asOf: WeeklyProgressFixtures.asOf,
                    calendar: WeeklyProgressFixtures.calendar
                )
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: weights.last?.weightKg,
                changeKg: nil,
                direction: .insufficientData,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            monthHealthWorkoutCount: healthWorkoutDayStarts.count,
            asOf: WeeklyProgressFixtures.asOf,
            calendar: WeeklyProgressFixtures.calendar
        )
    }
}
