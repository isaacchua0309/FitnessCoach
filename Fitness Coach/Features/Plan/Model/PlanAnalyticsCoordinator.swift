//
//  PlanAnalyticsCoordinator.swift
//  Fitness Coach
//
//  Forma — Plan tab analytics coordinator; weekly progress plan events delegate to
//  `WeeklyProgressAnalyticsCoordinator` (see `WeeklyProgressAnalyticsLogging.swift`).
//

import Foundation

@MainActor
final class PlanAnalyticsCoordinator {

    private let weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator

    init(weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator) {
        self.weeklyProgressAnalyticsCoordinator = weeklyProgressAnalyticsCoordinator
    }

    func updateWeeklyProgressContext(from summary: WeeklyProgressSummary) {
        weeklyProgressAnalyticsCoordinator.updateContext(from: summary)
    }

    func logWeeklyRecommendationShown(
        summary: WeeklyProgressSummary,
        recommendationKind: WeeklyPlanRecommendationKind?
    ) {
        weeklyProgressAnalyticsCoordinator.logPlanRecommendationShown(
            summary: summary,
            recommendationKind: recommendationKind,
            surface: .planDashboard
        )
    }

    func logWeeklyRecommendationTapped(
        summary: WeeklyProgressSummary,
        recommendationKind: WeeklyPlanRecommendationKind?
    ) {
        weeklyProgressAnalyticsCoordinator.logPlanRecommendationTapped(
            summary: summary,
            recommendationKind: recommendationKind,
            surface: .planDashboard,
            entryPoint: .planDashboard
        )
    }

    func logPlanEditStartedFromWeeklyReview(
        summary: WeeklyProgressSummary,
        entryPoint: WeeklyProgressAnalyticsEntryPoint,
        recommendationKind: WeeklyPlanRecommendationKind? = nil
    ) {
        weeklyProgressAnalyticsCoordinator.logPlanEditStartedFromWeeklyReview(
            summary: summary,
            entryPoint: entryPoint,
            recommendationKind: recommendationKind
        )
    }
}
