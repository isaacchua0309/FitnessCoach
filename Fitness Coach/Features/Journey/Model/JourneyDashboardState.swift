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
}

extension JourneyDashboardState {
    var weeklyReview: JourneyWeeklyReviewState {
        weeklyHabit.weeklyReviewState
    }

    var milestones: JourneyMilestonesState {
        milestone.milestonesState
    }

    var storyTimeline: JourneyStoryTimelineState {
        let events = storyEvents.map(\.timelineEvent)
        return JourneyStoryTimelineState(
            events: events,
            displayEvents: events,
            emptyStateMessage: events.isEmpty
                ? FormaProductCopy.Journey.Timeline.emptyBody
                : nil
        )
    }

    var hasMeaningfulJourneyData: Bool {
        weeklyHabit.showsHabitRows
            || !milestones.unlocked.isEmpty
            || baseline.hasRealWeightEntries
            || streaks.currentLoggingStreakDays >= 2
            || insight.isUnlocked
    }

    var showsMilestonesSection: Bool {
        milestone.isVisible
    }

    var showsStoryTimelineSection: Bool {
        hasMeaningfulJourneyData && !storyEvents.isEmpty
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
