//
//  HealthIntelligencePresentationStateMapper.swift
//  Fitness Coach
//
//  Forma — Maps health availability, sync, and snapshot signals into shared UI lifecycle states.
//

import Foundation

enum HealthIntelligencePresentationStateMapper {

    static func resolve(_ context: HealthIntelligencePresentationContext) -> HealthIntelligencePresentationLifecycle {
        if context.isLoading || context.syncPhase == .syncing {
            return .loading
        }

        if context.explicitErrorMessage != nil || context.syncPhase == .failed {
            return .syncFailed
        }

        if context.availability?.isHealthDataAvailable == false {
            return .unavailableOnDevice
        }

        if requiresHealthPermission(context) {
            return .noHealthPermission
        }

        if hasPartialHealthPermission(context) {
            return .partialHealthPermission
        }

        if hasNoHealthDataYet(context) {
            return .noHealthDataYet
        }

        if hasLimitedEstimate(context) {
            return .limitedEstimate
        }

        return .ready
    }

    static func message(
        for lifecycle: HealthIntelligencePresentationLifecycle,
        surface: HealthIntelligenceSurface = .today
    ) -> HealthIntelligencePresentationMessage {
        FormaProductCopy.HealthIntelligence.message(for: lifecycle, surface: surface)
    }

    static func bannerMessage(
        for context: HealthIntelligencePresentationContext,
        surface: HealthIntelligenceSurface = .today
    ) -> String? {
        let lifecycle = resolve(context)
        switch lifecycle {
        case .ready, .loading:
            return nil
        case .limitedEstimate:
            return message(for: lifecycle, surface: surface).bannerMessage
        default:
            return message(for: lifecycle, surface: surface).bannerMessage
        }
    }

    static func confidenceLabel(for lifecycle: HealthIntelligencePresentationLifecycle) -> String? {
        switch lifecycle {
        case .limitedEstimate:
            return FormaProductCopy.HealthIntelligence.limitedEstimateLabel
        case .partialHealthPermission:
            return FormaProductCopy.HealthIntelligence.partialDataLabel
        case .noHealthDataYet:
            return FormaProductCopy.HealthIntelligence.buildingLabel
        default:
            return nil
        }
    }

    static func connectionLevel(from context: HealthIntelligencePresentationContext) -> HealthIntelligenceConnectionLevel {
        if context.availability?.isHealthDataAvailable == false {
            return .unavailableOnDevice
        }

        if requiresHealthPermission(context) {
            return .disconnected
        }

        if hasPartialHealthPermission(context) {
            return .partial
        }

        if context.isAppleHealthConnected || context.availability?.hasAnyReadableSignal == true {
            return .connected
        }

        return .disconnected
    }

    // MARK: - Resolution helpers

    private static func requiresHealthPermission(_ context: HealthIntelligencePresentationContext) -> Bool {
        let status = HealthIntegrationStatusResolver.resolve(
            HealthIntegrationStatusInput(
                isHealthDataAvailable: context.availability?.isHealthDataAvailable ?? true,
                permissionStatus: context.availability?.permissionStatus,
                trainingIntegrationState: context.trainingIntegrationState,
                connectionRecord: context.connectionRecord,
                snapshot: context.snapshot,
                baseline: context.baseline,
                cachedDayCount: context.cachedDayCount
            )
        )
        return status.requiresInitialConnection(
            hasPriorConnectionEvidence: context.connectionRecord.hasPriorConnectionEvidence(
                trainingIntegrationState: context.trainingIntegrationState,
                permissionStatus: context.availability?.permissionStatus
            )
        )
    }

    private static func hasPartialHealthPermission(_ context: HealthIntelligencePresentationContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }

        guard let availability = context.availability else { return false }

        let connected = context.isAppleHealthConnected || availability.hasAnyReadableSignal
        guard connected else { return false }

        if availability.hasAnyReadableSignal, !availability.hasTrainingReadAccess {
            return true
        }

        if availability.hasAnyReadableSignal, !availability.permissionStatus.allRequiredSignalsAvailable {
            return true
        }

        if availability.permissionStatus.anyRequiredSignalDenied, availability.hasAnyReadableSignal {
            return true
        }

        return false
    }

    private static func hasNoHealthDataYet(_ context: HealthIntelligencePresentationContext) -> Bool {
        guard !requiresHealthPermission(context) else { return false }

        let connected = context.isAppleHealthConnected || context.availability?.hasAnyReadableSignal == true
        guard connected else { return false }

        if context.cachedDayCount > 0 {
            return false
        }

        guard let snapshot = context.snapshot else {
            return true
        }

        return !hasAnyRenderableSnapshotSignal(context)
            && snapshot.recovery.status == .unknown
            && snapshot.workout?.hasWorkout != true
    }

    private static func hasLimitedEstimate(_ context: HealthIntelligencePresentationContext) -> Bool {
        guard let recovery = context.snapshot?.recovery else { return false }
        guard hasAnyRenderableSnapshotSignal(context) else { return false }

        if recovery.confidence == .low || recovery.confidence == .unknown {
            return true
        }

        if recovery.status == .unknown, !recovery.missingSignals.isEmpty {
            return true
        }

        if !recovery.missingSignals.isEmpty,
           recovery.missingSignals.contains(.sleep),
           recovery.missingSignals.contains(where: { $0 == .hrv || $0 == .restingHeartRate }) {
            return true
        }

        return false
    }

    private static func hasAnyRenderableSnapshotSignal(_ context: HealthIntelligencePresentationContext) -> Bool {
        guard let snapshot = context.snapshot else { return false }

        if snapshot.workout?.hasWorkout == true {
            return true
        }

        let activity = snapshot.activity
        if activity.steps != nil || activity.activeEnergyKcal != nil || activity.exerciseMinutes != nil {
            return true
        }

        if snapshot.recovery.status != .unknown || snapshot.recovery.score != nil {
            return true
        }

        return false
    }
}

enum HealthIntelligenceConnectionLevel: Equatable, Sendable {
    case disconnected
    case partial
    case connected
    case unavailableOnDevice
}
