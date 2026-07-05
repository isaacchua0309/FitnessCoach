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
        milestone.isVisible
    }

    var showsStoryTimelineSection: Bool {
        hasMeaningfulJourneyData && !screenPresentation.story.events.isEmpty
    }

    var showsStartingEmptyState: Bool {
        !hasMeaningfulJourneyData
    }

    var showsMomentumSection: Bool {
        momentum.isVisible
    }

    var showsGoalProjectionSection: Bool {
        hasMeaningfulJourneyData && goalProjection.isVisible
    }

    var showsWeeklyReviewSection: Bool {
        hasMeaningfulJourneyData && weeklyHabit.isVisible
    }

    var showsWeeklyProgressSection: Bool {
        guard hasProfile else { return false }
        if weeklyProgressSummary.foodLoggedDays > 0 { return true }
        if weeklyHabit.showsHabitRows { return true }
        return hasMeaningfulJourneyData && weeklyHabit.isVisible
    }

    var showsInsightSection: Bool {
        hasMeaningfulJourneyData && insight.isVisible
    }

    var showsMonthlyRecapSection: Bool {
        hasMeaningfulJourneyData && monthlyRecap.isVisible
    }

    var showsChapterSection: Bool {
        hasMeaningfulJourneyData
    }
}
