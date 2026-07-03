//
//  HealthIntelligenceAnalyticsCoordinator.swift
//  Fitness Coach
//
//  Forma — Health Intelligence UI analytics (read-only, bucketed, privacy-safe).
//

import Foundation

@MainActor
final class HealthIntelligenceAnalyticsCoordinator {

    private let analyticsLogger: any HealthIntelligenceAnalyticsLogging
    private var basePropertiesBySurface: [HealthIntelligenceSurface: HealthIntelligenceAnalyticsProperties] = [:]
    private var loggedViewEvents: Set<String> = []

    init(analyticsLogger: any HealthIntelligenceAnalyticsLogging = NoOpHealthIntelligenceAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Context

    func updateContext(
        from context: HealthIntelligencePresentationContext,
        surface: HealthIntelligenceSurface,
        confidenceBucket: String? = nil
    ) {
        basePropertiesBySurface[surface] = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: context,
            surface: surface,
            confidenceBucket: confidenceBucket
        )
        resetViewEvents(for: surface)
    }

    func updateContext(
        from snapshot: HealthIntelligenceSnapshot?,
        surface: HealthIntelligenceSurface,
        isAppleHealthConnected: Bool = false,
        cachedDayCount: Int = 0,
        availability: HealthDataAvailability? = nil,
        confidenceBucket: String? = nil
    ) {
        basePropertiesBySurface[surface] = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: snapshot,
            surface: surface,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            availability: availability,
            confidenceBucket: confidenceBucket
        )
        resetViewEvents(for: surface)
    }

    // MARK: - Snapshot lifecycle

    func logSnapshotLoaded(
        surface: HealthIntelligenceSurface,
        context: HealthIntelligencePresentationContext,
        confidenceBucket: String? = nil
    ) {
        let properties = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: context,
            surface: surface,
            confidenceBucket: confidenceBucket
        )
        basePropertiesBySurface[surface] = properties
        resetViewEvents(for: surface)
        log(.snapshotLoaded, properties: properties)
    }

    func logSnapshotFailed(
        surface: HealthIntelligenceSurface,
        context: HealthIntelligencePresentationContext,
        error: Error? = nil,
        confidenceBucket: String? = nil
    ) {
        var properties = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: context,
            surface: surface,
            confidenceBucket: confidenceBucket
        )
        properties.failureReason = HealthIntelligenceAnalyticsContextBuilder.failureReason(
            for: error,
            context: context
        ).rawValue
        log(.snapshotFailed, properties: properties)
    }

    // MARK: - Today

    func logTodayRecoveryCardViewed() {
        logSectionOnce(.todayRecoveryCardViewed, surface: .today)
    }

    func logTodayNextBestActionTapped(destination: TodayHealthNextBestActionDestination) {
        guard destination != .none else { return }

        var properties = baseProperties(for: .today)
        properties.actionType = HealthIntelligenceAnalyticsContextBuilder.nextBestActionType(for: destination)
        log(.todayNextBestActionTapped, properties: properties)

        if destination == .connectHealth {
            logHealthPermissionCTATapped(surface: .today)
        }
    }

    // MARK: - Coach

    func logCoachHealthContextUsed(from snapshot: HealthIntelligenceSnapshot?) {
        var properties = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: snapshot,
            surface: .coach
        )
        if properties.confidenceBucket == nil, let snapshot {
            properties.confidenceBucket = HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(
                from: snapshot.planConfidence
            )
        }
        log(.coachHealthContextUsed, properties: properties)
    }

    func logCoachHealthContextAvailable(from snapshot: HealthIntelligenceSnapshot?) {
        var properties = coachContextProperties(from: snapshot)
        log(.coachHealthContextAvailable, properties: properties)
    }

    func logCoachHealthContextPartial(from snapshot: HealthIntelligenceSnapshot?) {
        var properties = coachContextProperties(from: snapshot)
        log(.coachHealthContextPartial, properties: properties)
    }

    // MARK: - Journey

    func logJourneyRecoveryTimelineViewed() {
        logSectionOnce(.journeyRecoveryTimelineViewed, surface: .journey)
    }

    func logJourneyWorkoutHistoryViewed() {
        logSectionOnce(.journeyWorkoutHistoryViewed, surface: .journey)
    }

    func logWeeklyReviewCardViewed() {
        logSectionOnce(.weeklyReviewCardViewed, surface: .journey)
    }

    func logWeeklyReviewDetailOpened() {
        var properties = baseProperties(for: .journey)
        log(.weeklyReviewDetailOpened, properties: properties)
    }

    // MARK: - Plan

    func logPlanHealthConfidenceViewed(confidenceBucket: String? = nil) {
        guard loggedViewEvents.insert(viewEventKey(.planHealthConfidenceViewed, surface: .plan)).inserted else {
            return
        }

        var properties = baseProperties(for: .plan)
        if let confidenceBucket {
            properties.confidenceBucket = confidenceBucket
        }
        log(.planHealthConfidenceViewed, properties: properties)
    }

    // MARK: - Permission CTA

    func logHealthPermissionCTATapped(surface: HealthIntelligenceAnalyticsPermissionCTASurface) {
        var properties = baseProperties(for: healthIntelligenceSurface(for: surface))
        properties.ctaSurface = surface.rawValue
        log(.healthPermissionCTATapped, properties: properties)
    }

    // MARK: - Private

    private func baseProperties(for surface: HealthIntelligenceSurface) -> HealthIntelligenceAnalyticsProperties {
        basePropertiesBySurface[surface] ?? HealthIntelligenceAnalyticsProperties(
            featureFlagState: HealthIntelligenceAnalyticsContextBuilder.featureFlagState(),
            surface: surface.rawValue
        )
    }

    private func coachContextProperties(
        from snapshot: HealthIntelligenceSnapshot?
    ) -> HealthIntelligenceAnalyticsProperties {
        var properties = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: snapshot,
            surface: .coach
        )
        if properties.confidenceBucket == nil, let snapshot {
            properties.confidenceBucket = HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(
                from: snapshot.planConfidence
            )
        }
        return properties
    }

    private func healthIntelligenceSurface(
        for surface: HealthIntelligenceAnalyticsPermissionCTASurface
    ) -> HealthIntelligenceSurface {
        switch surface {
        case .today: return .today
        case .journey: return .journey
        case .plan: return .plan
        }
    }

    private func resetViewEvents(for surface: HealthIntelligenceSurface) {
        loggedViewEvents = loggedViewEvents.filter { !$0.hasPrefix("\(surface.rawValue):") }
    }

    private func logSectionOnce(_ event: HealthIntelligenceAnalyticsEvent, surface: HealthIntelligenceSurface) {
        guard loggedViewEvents.insert(viewEventKey(event, surface: surface)).inserted else { return }
        log(event, properties: baseProperties(for: surface))
    }

    private func viewEventKey(
        _ event: HealthIntelligenceAnalyticsEvent,
        surface: HealthIntelligenceSurface
    ) -> String {
        "\(surface.rawValue):\(event.rawValue)"
    }

    private func log(
        _ event: HealthIntelligenceAnalyticsEvent,
        properties: HealthIntelligenceAnalyticsProperties
    ) {
        analyticsLogger.log(event, properties: properties)
    }
}
