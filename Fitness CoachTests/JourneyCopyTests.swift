//
//  JourneyCopyTests.swift
//  Fitness CoachTests
//
//  Forma — Journey copy namespaces, goal-direction variants, and tone guardrails.
//

import XCTest
@testable import Fitness_Coach

final class JourneyCopyTests: XCTestCase {

    private let shameTerms = [
        "failed",
        "bad",
        "poor",
        "off track",
        "behind",
        "weakest habit"
    ]

    // MARK: - Goal direction

    func testLoseCopyUsesDirectionalLanguage() {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let milestones = FormaProductCopy.Journey.Milestones.self
        let attribution = FormaProductCopy.Journey.ProgressAttribution.self

        XCTAssertTrue(transformation.lostHeadline.localizedCaseInsensitiveContains("lost"))
        XCTAssertTrue(milestones.firstKilogramTitle(direction: .lose).localizedCaseInsensitiveContains("lost"))
        XCTAssertTrue(attribution.weightTrendTowardGoal(direction: .lose).localizedCaseInsensitiveContains("goal"))
    }

    func testGainCopyUsesDirectionalLanguage() {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let milestones = FormaProductCopy.Journey.Milestones.self
        let attribution = FormaProductCopy.Journey.ProgressAttribution.self

        XCTAssertTrue(transformation.gainedHeadline.localizedCaseInsensitiveContains("gained"))
        XCTAssertTrue(milestones.firstKilogramTitle(direction: .gain).localizedCaseInsensitiveContains("gain"))
        XCTAssertFalse(milestones.firstKilogramTitle(direction: .gain).localizedCaseInsensitiveContains("lost"))
        XCTAssertTrue(attribution.weightTrendTowardGoal(direction: .gain).localizedCaseInsensitiveContains("gain"))
    }

    func testMaintainCopyAvoidsDirectionalWeightLanguage() {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let milestones = FormaProductCopy.Journey.Milestones.self
        let attribution = FormaProductCopy.Journey.ProgressAttribution.self

        XCTAssertTrue(transformation.maintainingHeadline.localizedCaseInsensitiveContains("maintain"))
        XCTAssertFalse(milestones.firstKilogramTitle(direction: .maintain).localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(milestones.firstKilogramTitle(direction: .maintain).localizedCaseInsensitiveContains("gained"))
        XCTAssertFalse(milestones.tenKilogramTitle(direction: .maintain).localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(attribution.weightTrendTowardGoal(direction: .maintain).localizedCaseInsensitiveContains("lost"))
    }

    // MARK: - Empty states

    func testEmptyCopyGuidesNextStep() {
        let emptyStates = [
            FormaProductCopy.Journey.EmptyState.weightTrendBody,
            FormaProductCopy.Journey.EmptyState.consistencyBody,
            FormaProductCopy.Journey.EmptyState.habitInsightsBody,
            FormaProductCopy.Journey.EmptyState.personalRecordsBody,
            FormaProductCopy.Journey.EmptyState.timelineBody,
            FormaProductCopy.Journey.EmptyState.milestonesBody,
            FormaProductCopy.Journey.EmptyState.levelBody,
            FormaProductCopy.Journey.Milestones.emptyBody,
            FormaProductCopy.Journey.Level.emptyBody,
            FormaProductCopy.Journey.WeeklyReview.noFoodLogsSummary,
            FormaProductCopy.Journey.WeeklyReview.weightUnavailable,
            FormaProductCopy.Journey.Timeline.emptyBody
        ]

        for body in emptyStates {
            XCTAssertFalse(body.isEmpty)
            XCTAssertTrue(
                body.localizedCaseInsensitiveContains("log")
                    || body.localizedCaseInsensitiveContains("keep")
                    || body.localizedCaseInsensitiveContains("start")
                    || body.localizedCaseInsensitiveContains("building")
                    || body.localizedCaseInsensitiveContains("today"),
                "Empty state should guide next step: \(body)"
            )
        }
    }

    // MARK: - Tone

    func testJourneyCopyAvoidsShameLanguage() {
        for sample in journeyCopySamples() {
            let lowered = sample.lowercased()
            for term in shameTerms {
                XCTAssertFalse(
                    lowered.contains(term),
                    "Unexpected shame term \"\(term)\" in: \(sample)"
                )
            }
        }
    }

    func testProgressAttributionUsesLikelyHelpedLanguage() {
        let attribution = FormaProductCopy.Journey.ProgressAttribution.self
        let titles = [
            attribution.calorieLikelyHelpedTitle,
            attribution.proteinAnchorTitle,
            attribution.loggingControlTitle,
            attribution.trainingRhythmTitle,
            attribution.waterSupportTitle,
            attribution.biggestReasonTitle
        ]

        for title in titles {
            XCTAssertTrue(
                title.localizedCaseInsensitiveContains("likely"),
                "Attribution title should hedge causality: \(title)"
            )
        }
    }

    func testTimelineAndStoryTimelineAliasMatch() {
        XCTAssertEqual(
            FormaProductCopy.Journey.Timeline.emptyBody,
            FormaProductCopy.Journey.StoryTimeline.emptyBody
        )
        XCTAssertEqual(
            FormaProductCopy.Journey.ProgressAttribution.sectionTitle,
            FormaProductCopy.Journey.WhyProgress.sectionTitle
        )
    }

    func testJourneyEmptyStateAliasesGlobalEmptyState() {
        XCTAssertEqual(
            FormaProductCopy.Journey.EmptyState.weightTrendBody,
            FormaProductCopy.EmptyState.WeightTrend.body
        )
        XCTAssertEqual(
            FormaProductCopy.Journey.EmptyState.consistencyBody,
            FormaProductCopy.EmptyState.Consistency.body
        )
    }

    // MARK: - Helpers

    private func journeyCopySamples() -> [String] {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let weekly = FormaProductCopy.Journey.WeeklyReview.self
        let milestones = FormaProductCopy.Journey.Milestones.self
        let timeline = FormaProductCopy.Journey.Timeline.self
        let habits = FormaProductCopy.Journey.HabitInsights.self
        let attribution = FormaProductCopy.Journey.ProgressAttribution.self
        let beforeToday = FormaProductCopy.Journey.BeforeToday.self
        let records = FormaProductCopy.Journey.PersonalRecords.self
        let recap = FormaProductCopy.Journey.MonthlyRecap.self
        let level = FormaProductCopy.Journey.Level.self
        let analytics = FormaProductCopy.Journey.DetailedAnalytics.self
        let empty = FormaProductCopy.Journey.EmptyState.self
        let streaks = FormaProductCopy.Journey.Streaks.self

        return [
            transformation.lostHeadline,
            transformation.gainedHeadline,
            transformation.maintainingHeadline,
            transformation.emotionalMomentumBuilding,
            transformation.emotionalAheadOfSchedule,
            transformation.paceForecastFallback,
            weekly.sectionTitle,
            weekly.noFoodLogsSummary,
            weekly.weightUnavailable,
            milestones.sectionTitle,
            milestones.emptyBody,
            milestones.loggedFirstMeal,
            milestones.firstKilogramTitle(direction: .lose),
            milestones.firstKilogramTitle(direction: .gain),
            milestones.firstKilogramTitle(direction: .maintain),
            timeline.sectionTitle,
            timeline.emptyBody,
            timeline.startedForma,
            habits.sectionTitle,
            habits.lockedBody,
            habits.strongestTitle,
            habits.nextFocusTitle,
            habits.suggestLogWeightTwice,
            habits.suggestLogNextMeal,
            attribution.sectionTitle,
            attribution.insufficientTitle,
            attribution.calorieLikelyHelpedTitle,
            attribution.weightTrendTowardGoal(direction: .lose),
            attribution.weightTrendTowardGoal(direction: .gain),
            attribution.weightTrendTowardGoal(direction: .maintain),
            beforeToday.sectionTitle,
            beforeToday.adaptedTargetCopy,
            records.sectionTitle,
            records.lockedBody,
            recap.buildingBody,
            recap.bestHabit(for: .protein),
            level.sectionTitle,
            level.emptyBody,
            level.earnExplanation,
            analytics.title,
            analytics.subtitle,
            analytics.WeightTrend.decreasing,
            analytics.WeightTrend.increasing,
            analytics.WeightTrend.stable,
            empty.habitInsightsBody,
            empty.milestonesBody,
            streaks.buildingConsistency,
            streaks.keepStreakAlive
        ]
    }
}
