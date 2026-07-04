//
//  WeeklyProgressAnalyticsCoordinator.swift
//  Fitness Coach
//
//  Forma — Weekly Progress Loop v1 analytics (read-only, bucketed, privacy-safe).
//

import Foundation

@MainActor
final class WeeklyProgressAnalyticsCoordinator {

    private let analyticsLogger: any WeeklyProgressAnalyticsLogging
    private var baseProperties: WeeklyProgressAnalyticsProperties = .init()
    private var loggedViewEvents: Set<String> = []

    init(analyticsLogger: any WeeklyProgressAnalyticsLogging = NoOpWeeklyProgressAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Context

    func updateContext(from summary: WeeklyProgressSummary) {
        baseProperties = WeeklyProgressAnalyticsContextBuilder.properties(from: summary)
        resetViewEvents()
    }

    func updateContext(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        calendarSpanDays: Int,
        confidence: WeeklyProgressConfidenceLevel,
        hasWeightSpike: Bool = false,
        hasMaintenanceEstimate: Bool = false
    ) {
        baseProperties = WeeklyProgressAnalyticsContextBuilder.properties(
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            confidence: confidence,
            hasWeightSpike: hasWeightSpike,
            hasMaintenanceEstimate: hasMaintenanceEstimate
        )
        resetViewEvents()
    }

    // MARK: - Journey card & detail

    func logCardViewed(
        summary: WeeklyProgressSummary,
        freshnessInput: WeeklyProgressFreshnessInput? = nil
    ) {
        guard loggedViewEvents.insert(viewEventKey(.cardViewed, surface: .journeyCard)).inserted else {
            return
        }

        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            surface: .journeyCard
        )
        log(.cardViewed, properties: properties)

        if WeeklyProgressAnalyticsContextBuilder.isStaleOrSyncing(freshnessInput) {
            logStaleOrSyncing(
                summary: summary,
                surface: .journeyCard,
                freshnessInput: freshnessInput
            )
        }
    }

    func logReviewOpened(summary: WeeklyProgressSummary) {
        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            surface: .journeyDetail,
            entryPoint: .journeyCard
        )
        log(.reviewOpened, properties: properties)
    }

    func logReviewCompleted(summary: WeeklyProgressSummary) {
        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            surface: .journeyDetail
        )
        log(.reviewCompleted, properties: properties)
    }

    func logRestorePending() {
        log(.restorePending, properties: baseProperties)
    }

    func logStaleOrSyncing(
        summary: WeeklyProgressSummary,
        surface: WeeklyProgressAnalyticsSurface,
        freshnessInput: WeeklyProgressFreshnessInput?
    ) {
        guard WeeklyProgressAnalyticsContextBuilder.isStaleOrSyncing(freshnessInput) else { return }
        guard loggedViewEvents.insert(viewEventKey(.staleOrSyncing, surface: surface)).inserted else {
            return
        }

        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            surface: surface
        )
        log(.staleOrSyncing, properties: properties)
    }

    // MARK: - Maintenance

    func logMaintenanceBlockViewed(
        summary: WeeklyProgressSummary,
        showsLearnedEstimate: Bool,
        surface: WeeklyProgressAnalyticsSurface
    ) {
        guard loggedViewEvents.insert(
            viewEventKey(.maintenanceEstimateShown, surface: surface, suffix: "maintenance")
        ).inserted else {
            return
        }

        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            surface: surface
        )

        if showsLearnedEstimate {
            log(.maintenanceEstimateShown, properties: properties)
            if summary.maintenanceEstimate.confidence == .low || summary.confidence == .low {
                log(.maintenanceConfidenceLow, properties: properties)
            }
        } else {
            log(.maintenanceEstimateInsufficientData, properties: properties)
        }
    }

    // MARK: - Plan recommendation

    func logPlanRecommendationShown(
        summary: WeeklyProgressSummary,
        recommendationKind: WeeklyPlanRecommendationKind?,
        surface: WeeklyProgressAnalyticsSurface
    ) {
        guard recommendationKind != nil, recommendationKind != .notEnoughData else { return }
        guard loggedViewEvents.insert(
            viewEventKey(.planRecommendationShown, surface: surface, suffix: recommendationKind?.rawValue)
        ).inserted else {
            return
        }

        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            recommendationKind: recommendationKind,
            surface: surface
        )
        log(.planRecommendationShown, properties: properties)
    }

    func logPlanRecommendationTapped(
        summary: WeeklyProgressSummary,
        recommendationKind: WeeklyPlanRecommendationKind?,
        surface: WeeklyProgressAnalyticsSurface,
        entryPoint: WeeklyProgressAnalyticsEntryPoint
    ) {
        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            recommendationKind: recommendationKind,
            surface: surface,
            entryPoint: entryPoint
        )
        log(.planRecommendationTapped, properties: properties)
    }

    func logPlanEditStartedFromWeeklyReview(
        summary: WeeklyProgressSummary,
        entryPoint: WeeklyProgressAnalyticsEntryPoint,
        recommendationKind: WeeklyPlanRecommendationKind? = nil
    ) {
        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            recommendationKind: recommendationKind,
            surface: .planDashboard,
            entryPoint: entryPoint
        )
        log(.planEditStartedFromWeeklyReview, properties: properties)
    }

    func logPlanEditStartedFromWeeklyReview(
        recommendationKind: WeeklyPlanRecommendationKind?,
        entryPoint: WeeklyProgressAnalyticsEntryPoint,
        foodLoggedDays: Int = 0,
        weightEntryCount: Int = 0,
        calendarSpanDays: Int = 7,
        confidence: WeeklyProgressConfidenceLevel = .unavailable,
        hasWeightSpike: Bool = false,
        hasMaintenanceEstimate: Bool = false
    ) {
        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            confidence: confidence,
            hasWeightSpike: hasWeightSpike,
            hasMaintenanceEstimate: hasMaintenanceEstimate,
            recommendationKind: recommendationKind,
            surface: .planDashboard,
            entryPoint: entryPoint
        )
        log(.planEditStartedFromWeeklyReview, properties: properties)
    }

    // MARK: - Weight spike

    func logWeightSpikeExplanationShown(
        summary: WeeklyProgressSummary,
        surface: WeeklyProgressAnalyticsSurface
    ) {
        guard summary.hasSuddenSpike else { return }
        guard loggedViewEvents.insert(
            viewEventKey(.weightSpikeExplanationShown, surface: surface)
        ).inserted else {
            return
        }

        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            surface: surface
        )
        log(.weightSpikeExplanationShown, properties: properties)
    }

    // MARK: - Today daily review teaser

    func logDailyReviewTeaserViewed(
        foodLoggedDays: Int,
        weightEntryCount: Int = 0,
        calendarSpanDays: Int = 1
    ) {
        guard loggedViewEvents.insert(viewEventKey(.dailyReviewTeaserViewed, surface: .todayTeaser)).inserted else {
            return
        }

        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            confidence: .unavailable,
            surface: .todayTeaser
        )
        log(.dailyReviewTeaserViewed, properties: properties)
    }

    func logDailyReviewOpenedFromToday(foodLoggedDays: Int) {
        var properties = WeeklyProgressAnalyticsContextBuilder.properties(
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: 0,
            calendarSpanDays: 1,
            confidence: .unavailable,
            surface: .todayTeaser,
            entryPoint: .todayTeaser
        )
        log(.dailyReviewOpenedFromToday, properties: properties)
    }

    // MARK: - Private

    private func resetViewEvents() {
        loggedViewEvents.removeAll()
    }

    private func viewEventKey(
        _ event: WeeklyProgressAnalyticsEvent,
        surface: WeeklyProgressAnalyticsSurface,
        suffix: String? = nil
    ) -> String {
        if let suffix {
            return "\(surface.rawValue):\(event.rawValue):\(suffix)"
        }
        return "\(surface.rawValue):\(event.rawValue)"
    }

    private func log(
        _ event: WeeklyProgressAnalyticsEvent,
        properties: WeeklyProgressAnalyticsProperties
    ) {
        analyticsLogger.log(event, properties: properties)
    }
}
