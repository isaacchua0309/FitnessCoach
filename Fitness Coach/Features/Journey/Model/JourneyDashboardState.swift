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
    var transformationHero: JourneyTransformationHeroState {
        transformation.heroState
    }

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

    var showsMilestonesSection: Bool {
        milestone.isVisible
    }

    var showsStoryTimelineSection: Bool {
        !storyEvents.isEmpty
    }

    var showsStartingEmptyState: Bool {
        !showsMilestonesSection && !showsStoryTimelineSection
    }

    var showsMomentumSection: Bool {
        momentum.isVisible
    }

    var showsGoalProjectionSection: Bool {
        goalProjection.isVisible
    }

    var showsInsightSection: Bool {
        insight.isVisible
    }

    var showsMonthlyRecapSection: Bool {
        monthlyRecap.isVisible
    }

    var showsChapterSection: Bool {
        chapter.isVisible
    }
}
