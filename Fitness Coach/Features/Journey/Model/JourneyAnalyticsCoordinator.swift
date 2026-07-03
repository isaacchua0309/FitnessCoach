//
//  JourneyAnalyticsCoordinator.swift
//  Fitness Coach
//
//  Forma — Journey screen and interaction analytics (read-only, bucketed).
//

import Foundation

@MainActor
final class JourneyAnalyticsCoordinator {

    private let analyticsLogger: any JourneyAnalyticsLogging
    private var snapshot: JourneyAnalyticsSnapshot = .empty
    private var loggedSectionEvents: Set<JourneyAnalyticsEvent> = []
    private var hasLoggedScreenView = false

    init(analyticsLogger: any JourneyAnalyticsLogging = NoOpJourneyAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Context

    func updateContext(from state: JourneyDashboardState, healthConnected: Bool) {
        snapshot = JourneyAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: healthConnected
        )
        resetSession()
    }

    func updateContextForEmptyProfile(healthConnected: Bool) {
        snapshot = JourneyAnalyticsSnapshot(
            hasProfile: false,
            hasWeightLogs: false,
            usesSyntheticBaseline: false,
            progressPercentBucket: JourneyAnalyticsProgressPercentBucket.none.rawValue,
            currentStreakBucket: JourneyAnalyticsStreakBucket.zero.rawValue,
            unlockedMilestoneCount: 0,
            healthConnected: healthConnected
        )
        resetSession()
    }

    // MARK: - Screen & sections

    func logScreenViewed() {
        guard !hasLoggedScreenView else { return }
        hasLoggedScreenView = true
        log(.screenViewed)
    }

    func logTransformationViewed() {
        logSectionOnce(.transformationViewed)
    }

    func logWeeklyReviewViewed() {
        logSectionOnce(.weeklyReviewViewed)
    }

    func logMilestoneRailViewed() {
        logSectionOnce(.milestoneRailViewed)
    }

    func logTimelineViewed() {
        logSectionOnce(.timelineViewed)
    }

    func logStartingEmptyStateViewed() {
        logSectionOnce(.startingEmptyStateViewed)
    }

    // MARK: - Interactions

    func logCTATapped(_ cta: JourneyCTA) {
        switch cta {
        case .logWeight:
            log(.weightCTATapped, ctaType: JourneyAnalyticsContextBuilder.ctaType(for: cta))
        case .logFood, .logWater, .logProtein:
            log(.coachCTATapped, ctaType: JourneyAnalyticsContextBuilder.ctaType(for: cta))
        case .connectAppleHealth, .updateGoal:
            break
        }
    }

    // MARK: - Private

    private func resetSession() {
        loggedSectionEvents.removeAll()
        hasLoggedScreenView = false
    }

    private func logSectionOnce(_ event: JourneyAnalyticsEvent) {
        guard !loggedSectionEvents.contains(event) else { return }
        loggedSectionEvents.insert(event)
        log(event)
    }

    private func log(
        _ event: JourneyAnalyticsEvent,
        ctaType: String? = nil
    ) {
        var properties = JourneyAnalyticsContextBuilder.properties(from: snapshot)
        properties.ctaType = ctaType
        analyticsLogger.log(event, properties: properties)
    }
}
