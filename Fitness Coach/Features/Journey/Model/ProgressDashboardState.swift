//
//  ProgressDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Unified immutable Journey “fitness story” dashboard payload.
//

import Foundation

struct ProgressDashboardState: Equatable {
    var selectedRangeDays: Int
    var hasProfile: Bool

    var baseline: JourneyBaseline
    var transformation: JourneyTransformationHeroState
    var weeklyReview: JourneyWeeklyReviewState
    var milestones: JourneyMilestonesState
    var storyTimeline: JourneyStoryTimelineState
    var habitInsights: JourneyHabitInsightsState
    var progressAttribution: JourneyProgressAttributionState
    var beforeToday: JourneyBeforeTodayState
    var personalRecords: JourneyPersonalRecordsState
    var monthlyRecap: JourneyMonthlyRecapState
    var journeyLevel: JourneyLevelState
    var detailedAnalytics: JourneyDetailedAnalyticsState
}
