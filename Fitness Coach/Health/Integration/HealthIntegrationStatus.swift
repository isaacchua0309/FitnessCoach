//
//  HealthIntegrationStatus.swift
//  Fitness Coach
//
//  Forma — Canonical Apple Health connection state (distinct from data availability).
//

import Foundation

enum HealthIntegrationStatus: String, Equatable, Sendable, Codable, CaseIterable {
    case unavailableOnDevice
    case notRequested
    case permissionDenied
    case connectedNoData
    case connectedPartial
    case connectedReady
    case unknown
}

extension HealthIntegrationStatus {

    /// User still needs the first-time Apple Health connection flow.
    func requiresInitialConnection(hasPriorConnectionEvidence: Bool) -> Bool {
        switch self {
        case .notRequested, .permissionDenied:
            return true
        case .unknown:
            return !hasPriorConnectionEvidence
        case .unavailableOnDevice, .connectedNoData, .connectedPartial, .connectedReady:
            return false
        }
    }

    var isConnected: Bool {
        switch self {
        case .connectedNoData, .connectedPartial, .connectedReady:
            return true
        case .unavailableOnDevice, .notRequested, .permissionDenied, .unknown:
            return false
        }
    }

    var canReviewPermissions: Bool {
        switch self {
        case .connectedPartial, .permissionDenied:
            return true
        case .unavailableOnDevice, .notRequested, .connectedNoData, .connectedReady, .unknown:
            return false
        }
    }
}

struct HealthIntegrationStatusInput: Equatable, Sendable {
    var isHealthDataAvailable: Bool
    var permissionStatus: HealthPermissionStatus?
    var trainingIntegrationState: TrainingIntegrationState
    var connectionRecord: HealthIntegrationConnectionRecord
    var snapshot: HealthIntelligenceSnapshot?
    var baseline: HealthBaselineContext?
    var cachedDayCount: Int = 0

    var hasPriorConnectionEvidence: Bool {
        connectionRecord.hasPriorConnectionEvidence(
            trainingIntegrationState: trainingIntegrationState,
            permissionStatus: permissionStatus
        )
    }
}

enum HealthIntegrationStatusResolver {

    static func resolve(_ input: HealthIntegrationStatusInput) -> HealthIntegrationStatus {
        guard input.isHealthDataAvailable else {
            return .unavailableOnDevice
        }

        let permission = input.permissionStatus
        let record = input.connectionRecord
        let integration = input.trainingIntegrationState
        let hasReadableSignal = permission?.hasAnyReadableSignal == true
        let completedFlow = record.hasCompletedAppleHealthConnectionFlow

        switch integration {
        case .unavailable:
            return .unavailableOnDevice
        case .denied:
            return .permissionDenied
        case .failed:
            return completedFlow || hasReadableSignal ? .connectedPartial : .permissionDenied
        case .requestingPermission:
            return completedFlow || hasReadableSignal ? .connectedNoData : .notRequested
        case .notConnected:
            if completedFlow || hasReadableSignal {
                return classifyConnectedDataState(input)
            }
            return .notRequested
        case .connected:
            return classifyConnectedDataState(input)
        }
    }

    static func resolveSignalAvailability(from input: HealthIntegrationStatusInput) -> HealthSignalAvailability {
        HealthSignalAvailabilityResolver.resolve(from: input)
    }

    // MARK: - Private

    private static func classifyConnectedDataState(
        _ input: HealthIntegrationStatusInput
    ) -> HealthIntegrationStatus {
        let signals = HealthSignalAvailabilityResolver.resolve(from: input)

        if hasRenderableTodayInsight(input, signals: signals) {
            return .connectedReady
        }

        if hasPartialPermission(input) || (signals.hasMissingSignals && signals.hasAnyAvailableData) {
            return .connectedPartial
        }

        if input.permissionStatus?.anyRequiredSignalDenied == true, signals.hasAnyAvailableData {
            return .connectedPartial
        }

        return .connectedNoData
    }

    private static func hasRenderableTodayInsight(
        _ input: HealthIntegrationStatusInput,
        signals: HealthSignalAvailability
    ) -> Bool {
        guard let snapshot = input.snapshot else {
            return input.cachedDayCount > 0 && signals.hasAnyAvailableData
        }

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

        return signals.hasAnyAvailableData && input.cachedDayCount > 0
    }

    private static func hasPartialPermission(_ input: HealthIntegrationStatusInput) -> Bool {
        guard let permission = input.permissionStatus else { return false }
        guard permission.hasAnyReadableSignal else { return false }

        if permission.hasAnyReadableSignal, !permission.hasTrainingReadAccess {
            return true
        }

        if permission.hasAnyReadableSignal, !permission.allRequiredSignalsAvailable {
            return true
        }

        if permission.anyRequiredSignalDenied, permission.hasAnyReadableSignal {
            return true
        }

        return false
    }
}
