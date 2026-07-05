//
//  JourneyAnalyticsCoordinator.swift
//  Fitness Coach
//
//  Forma — Journey screen and interaction analytics (read-only, bucketed).
//  Weekly Progress Loop v1 events: `WeeklyProgressAnalyticsCoordinator`.
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
        snapshot = .empty
        snapshot.healthConnected = healthConnected
        resetSession()
    }

    // MARK: - Screen & sections

    func logViewed() {
        guard !hasLoggedScreenView else { return }
        hasLoggedScreenView = true
        log(.viewed)
    }

    func logHeroViewed() {
        logSectionOnce(.heroViewed)
    }

    func logProjectionViewed() {
        logSectionOnce(.projectionViewed)
    }

    func logMilestoneViewed() {
        logSectionOnce(.milestoneViewed)
    }

    func logWeeklyConsistencyViewed() {
        logSectionOnce(.weeklyConsistencyViewed)
    }

    func logStoryViewed() {
        logSectionOnce(.storyViewed)
    }

    func logInsightsViewed() {
        logSectionOnce(.insightsViewed)
    }

    func logMonthlyRecapViewed() {
        logSectionOnce(.monthlyRecapViewed)
    }

    func logChapterViewed() {
        logSectionOnce(.chapterViewed)
    }

    // MARK: - Interactions

    func logGoToTodayTapped() {
        log(.goToTodayTapped)
    }

    func logCTATapped(_ cta: JourneyCTA) {
        let ctaType = JourneyAnalyticsContextBuilder.ctaType(for: cta)

        switch cta {
        case .logWeight:
            log(.weightCTATapped, ctaType: ctaType)
        case .logFood, .logWater, .logProtein:
            log(.coachCTATapped, ctaType: ctaType)
        case .connectAppleHealth, .updateGoal:
            break
        }

        if JourneyAnalyticsContextBuilder.isMilestoneAdvancingCTA(cta) {
            log(.milestoneCTATapped, ctaType: ctaType)
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
