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

    private let removedLegacyPhrases = [
        "Keep logging to unlock personal records",
        "Detailed analytics",
        "Before vs today",
        "Your consistency is starting to create a useful pattern",
        "Keep logging to unlock habit insights",
        "/ 25 XP",
        "Level 1 /"
    ]

    // MARK: - Goal direction

    func testLoseCopyUsesDirectionalLanguage() {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let milestones = FormaProductCopy.Journey.Milestones.self

        XCTAssertTrue(transformation.lostHeadline.localizedCaseInsensitiveContains("lost"))
        XCTAssertTrue(milestones.firstKilogramTitle(direction: .lose).localizedCaseInsensitiveContains("lost"))
    }

    func testGainCopyUsesDirectionalLanguage() {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let milestones = FormaProductCopy.Journey.Milestones.self

        XCTAssertTrue(transformation.gainedHeadline.localizedCaseInsensitiveContains("gained"))
        XCTAssertTrue(milestones.firstKilogramTitle(direction: .gain).localizedCaseInsensitiveContains("gain"))
        XCTAssertFalse(milestones.firstKilogramTitle(direction: .gain).localizedCaseInsensitiveContains("lost"))
    }

    func testMaintainCopyAvoidsDirectionalWeightLanguage() {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let milestones = FormaProductCopy.Journey.Milestones.self

        XCTAssertTrue(transformation.maintainingHeadline.localizedCaseInsensitiveContains("maintain"))
        XCTAssertFalse(milestones.firstKilogramTitle(direction: .maintain).localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(milestones.firstKilogramTitle(direction: .maintain).localizedCaseInsensitiveContains("gained"))
        XCTAssertFalse(milestones.tenKilogramTitle(direction: .maintain).localizedCaseInsensitiveContains("lost"))
    }

    // MARK: - Empty states

    func testEmptyCopyGuidesNextStep() {
        let emptyStates = [
            FormaProductCopy.Journey.EmptyState.weightTrendBody,
            FormaProductCopy.Journey.EmptyState.consistencyBody,
            FormaProductCopy.Journey.EmptyState.timelineBody,
            FormaProductCopy.Journey.EmptyState.milestonesBody,
            FormaProductCopy.Journey.Chapters.emptyBody,
            FormaProductCopy.Journey.WeeklyReview.noFoodLogsSummary,
            FormaProductCopy.Journey.WeeklyReview.weightUnavailable,
            FormaProductCopy.Journey.Timeline.emptyBody,
            FormaProductCopy.Journey.StartingEmptyState.body
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

    func testRevampCopyExcludesRemovedLegacyPhrases() {
        for sample in journeyCopySamples() {
            for phrase in removedLegacyPhrases {
                XCTAssertFalse(
                    sample.localizedCaseInsensitiveContains(phrase),
                    "Removed legacy phrase \"\(phrase)\" found in: \(sample)"
                )
            }
        }
    }

    func testTimelineAndStoryTimelineAliasMatch() {
        XCTAssertEqual(
            FormaProductCopy.Journey.Timeline.emptyBody,
            FormaProductCopy.Journey.StoryTimeline.emptyBody
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

    func testChaptersUseChapterLanguageNotCosmeticXP() {
        let chapters = FormaProductCopy.Journey.Chapters.self
        XCTAssertEqual(chapters.chapterLabel(1), "Chapter 1")
        XCTAssertTrue(chapters.nextUnlock("Creating Consistency").contains("Creating Consistency"))
        XCTAssertFalse(chapters.sectionTitle.localizedCaseInsensitiveContains("xp"))
    }

    // MARK: - Helpers

    private func journeyCopySamples() -> [String] {
        let transformation = FormaProductCopy.Journey.Transformation.self
        let weekly = FormaProductCopy.Journey.WeeklyReview.self
        let milestones = FormaProductCopy.Journey.Milestones.self
        let timeline = FormaProductCopy.Journey.Timeline.self
        let insights = FormaProductCopy.Journey.PersonalizedInsights.self
        let recap = FormaProductCopy.Journey.MonthlyRecap.self
        let chapters = FormaProductCopy.Journey.Chapters.self
        let empty = FormaProductCopy.Journey.EmptyState.self
        let starting = FormaProductCopy.Journey.StartingEmptyState.self
        let streaks = FormaProductCopy.Journey.Streaks.self
        let momentum = FormaProductCopy.Journey.Momentum.self

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
            insights.sectionTitle,
            insights.learningTitle,
            insights.learningDetail,
            insights.proteinStrongestTitle,
            insights.bestHabitTitle,
            recap.buildingBody,
            recap.teaserDetail,
            recap.teaserTitle(monthName: "July"),
            recap.bestHabit(for: .protein),
            chapters.sectionTitle,
            chapters.emptyBody,
            chapters.title(for: 1),
            chapters.nextUnlock(chapters.title(for: 2)),
            empty.weightTrendBody,
            empty.milestonesBody,
            starting.title,
            starting.body,
            starting.action,
            streaks.buildingConsistency,
            streaks.keepStreakAlive,
            momentum.buildingHeadline,
            momentum.activeHeadline(days: 3)
        ]
    }
}
