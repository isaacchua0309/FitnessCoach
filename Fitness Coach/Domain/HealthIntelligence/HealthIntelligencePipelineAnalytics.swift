//
//  HealthIntelligencePipelineAnalytics.swift
//  Fitness Coach
//
//  Forma — Pipeline analytics bridge for Health Intelligence services.
//  Privacy: counts, phases, and bucketed states only — never raw health values.
//

import Foundation

enum HealthIntelligencePermissionAnalyticsBucket: String, Sendable {
    case connected
    case partial
}

enum HealthIntelligencePipelineAnalytics {

    nonisolated(unsafe) private static var logger: (any HealthIntelligenceAnalyticsLogging)?

    static func register(_ logger: any HealthIntelligenceAnalyticsLogging) {
        self.logger = logger
    }

    static func resetForTesting() {
        logger = nil
    }

    private static var isEnabled: Bool {
        HealthIntelligenceFeatureFlags.healthIntelligencePipelineAnalyticsEnabled
    }

    static func logPermissionResolved(_ status: HealthPermissionStatus) {
        guard let bucket = permissionBucket(from: status) else { return }
        let event: HealthIntelligenceAnalyticsEvent = bucket == .connected
            ? .healthPermissionConnected
            : .healthPermissionPartial
        log(
            event,
            properties: HealthIntelligenceAnalyticsProperties(
                availableSignalCount: status.availableSignals.count,
                deniedSignalCount: status.deniedSignals.count,
                featureFlagState: HealthIntelligenceAnalyticsContextBuilder.featureFlagState()
            )
        )
    }

    static func logLocalSyncFinished(_ state: HealthSyncState, durationMs: Int) {
        let event: HealthIntelligenceAnalyticsEvent
        switch state.phase {
        case .succeeded, .partialSuccess:
            event = .healthLocalSyncSuccess
        case .failed:
            event = .healthLocalSyncFailed
        default:
            return
        }

        log(
            event,
            properties: HealthIntelligenceAnalyticsProperties(
                syncDurationMs: durationMs,
                syncTrigger: state.trigger?.rawValue,
                syncPhase: state.phase.rawValue,
                failureReason: state.lastError?.localizedDescription,
                featureFlagState: HealthIntelligenceAnalyticsContextBuilder.featureFlagState()
            )
        )
    }

    static func logSnapshotComposed(
        mode: HealthIntelligenceComposeMode,
        dataGapCount: Int,
        recoveryStatus: String,
        hasWorkout: Bool
    ) {
        log(
            .healthSnapshotComposed,
            properties: HealthIntelligenceAnalyticsProperties(
                composeMode: mode.logLabel,
                dataGapCount: dataGapCount,
                recoveryStatus: recoveryStatus,
                hasWorkoutToday: hasWorkout,
                featureFlagState: HealthIntelligenceAnalyticsContextBuilder.featureFlagState()
            )
        )
    }

    static func logRemoteSyncFinished(
        phase: HealthSummaryRemoteSyncPhase,
        trigger: String,
        dailyCount: Int,
        workoutCount: Int,
        recoveryCount: Int,
        errorDescription: String?
    ) {
        let event: HealthIntelligenceAnalyticsEvent
        switch phase {
        case .succeeded:
            event = .healthRemoteSyncSuccess
        case .partialSuccess, .failed:
            event = .healthRemoteSyncFailed
        default:
            return
        }

        log(
            event,
            properties: HealthIntelligenceAnalyticsProperties(
                syncTrigger: trigger,
                syncPhase: phase.rawValue,
                payloadDailyCount: dailyCount,
                payloadWorkoutCount: workoutCount,
                payloadRecoveryCount: recoveryCount,
                failureReason: errorDescription,
                featureFlagState: HealthIntelligenceAnalyticsContextBuilder.featureFlagState()
            )
        )
    }

    static func logCoachHealthContextAvailability(isPartial: Bool, missingSignalCount: Int) {
        let event: HealthIntelligenceAnalyticsEvent = isPartial
            ? .coachHealthContextPartial
            : .coachHealthContextAvailable
        log(
            event,
            properties: HealthIntelligenceAnalyticsProperties(
                missingSignalCount: missingSignalCount,
                featureFlagState: HealthIntelligenceAnalyticsContextBuilder.featureFlagState(),
                surface: HealthIntelligenceSurface.coach.rawValue
            )
        )
    }

    // MARK: - Private

    private static func permissionBucket(
        from status: HealthPermissionStatus
    ) -> HealthIntelligencePermissionAnalyticsBucket? {
        guard status.isHealthDataAvailable, status.hasAnyAvailableReadAccess else {
            return nil
        }
        return status.allRequiredSignalsAvailable ? .connected : .partial
    }

    private static func log(
        _ event: HealthIntelligenceAnalyticsEvent,
        properties: HealthIntelligenceAnalyticsProperties
    ) {
        guard isEnabled, let logger else { return }
        logger.log(event, properties: properties)
    }
}
