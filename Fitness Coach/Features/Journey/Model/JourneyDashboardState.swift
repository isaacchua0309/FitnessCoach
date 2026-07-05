//
//  JourneyDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Unified immutable Journey “fitness story” dashboard payload.
//

import Foundation

struct JourneyDashboardState: Equatable {
    var hasProfile: Bool

    var baseline: JourneyBaseline
    var streaks: JourneyStreakState
    var screenPresentation: JourneyScreenPresentationState
    var unifiedWeeklyReview: UnifiedWeeklyReviewState

    var dashboardHero: JourneyDashboardHeroState
    var progressSection: JourneyProgressSectionState

    var header: JourneyHeaderState
    var momentum: JourneyMomentumState
    var transformation: JourneyTransformationState
    var goalProjection: JourneyGoalProjectionState
    var milestone: JourneyMilestoneState
    var storyEvents: [JourneyStoryEvent]
    var insight: JourneyInsightState
    var weeklyHabit: JourneyWeeklyHabitState
    var monthlyRecap: JourneyMonthlyRecapState
    var chapter: JourneyChapterState
    var weeklyProgressSummary: WeeklyProgressSummary
    var dailyReviewsThisWeekCount: Int
}

extension JourneyDashboardState {
    var weeklyReview: JourneyWeeklyReviewState {
        weeklyHabit.weeklyReviewState
    }

    var milestones: JourneyMilestonesState {
        milestone.milestonesState
    }

    var storyTimeline: JourneyStoryTimelineState {
        let events = screenPresentation.story.events.map(\.timelineEvent)
        return JourneyStoryTimelineState(
            events: events,
            displayEvents: events,
            emptyStateMessage: events.isEmpty
                ? FormaProductCopy.Journey.Timeline.emptyBody
                : nil
        )
    }

    var storyEventsFromPresentation: [JourneyStoryEvent] {
        screenPresentation.story.events
    }

    var hasMeaningfulJourneyData: Bool {
        weeklyHabit.showsHabitRows
            || !milestones.unlocked.isEmpty
            || baseline.hasRealWeightEntries
            || screenPresentation.streaks.checkInStreakDays >= JourneyThresholds.meaningfulCheckInStreakDays
            || insight.isUnlocked
    }

    var showsMilestonesSection: Bool {
        guard milestone.isVisible else { return false }
        return !screenPresentation.unlockDashboard.suppressesMilestonesSection
    }

    var showsStoryTimelineSection: Bool {
        !screenPresentation.story.events.isEmpty
    }

    var showsChapterSection: Bool {
        hasProfile
    }

    var showsWeeklyProgressSection: Bool {
        hasProfile
    }

    var showsProgressSection: Bool {
        hasProfile && progressSection.isVisible
    }

    var showsHighlightsSection: Bool {
        false
    }

    var showsNextActionSection: Bool {
        screenPresentation.unlockDashboard.showsProminentNextActionCard
            && screenPresentation.unlockDashboard.nextActionCard != nil
    }

    var showsDashboardHeroSection: Bool {
        hasProfile && dashboardHero.isVisible
    }

    // MARK: - Legacy visibility (analytics + tests)

    var showsStartingEmptyState: Bool { false }

    var showsMomentumSection: Bool { false }

    var showsGoalProjectionSection: Bool {
        switch goalProjection.status {
        case .hidden, .insufficientData:
            return false
        case .towardGoal, .flatTrend, .awayFromGoal, .goalReached:
            return true
        }
    }

    var showsWeeklyReviewSection: Bool { false }

    var showsInsightSection: Bool { false }

    var showsMonthlyRecapSection: Bool { false }
}
