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
    var transformation: JourneyTransformationHeroState
    var weeklyReview: JourneyWeeklyReviewState
    var streaks: JourneyStreakState
    var milestones: JourneyMilestonesState
    var storyTimeline: JourneyStoryTimelineState
}

extension JourneyDashboardState {
    var showsMilestonesSection: Bool {
        !milestones.unlocked.isEmpty
            || milestones.items.contains { $0.status == .completed }
            || (milestones.nextProgressFraction ?? 0) > 0
    }

    var showsStoryTimelineSection: Bool {
        !storyTimeline.displayEvents.isEmpty
    }

    var showsStartingEmptyState: Bool {
        !showsMilestonesSection && !showsStoryTimelineSection
    }
}
