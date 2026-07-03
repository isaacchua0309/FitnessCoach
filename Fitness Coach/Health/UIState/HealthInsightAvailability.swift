//
//  HealthInsightAvailability.swift
//  Fitness Coach
//
//  Forma — Per-signal availability for Health Intelligence UI surfaces.
//

import Foundation

/// Insight channels that Health Intelligence surfaces may reference.
enum HealthInsightKind: String, Equatable, Sendable, Hashable, Codable, CaseIterable {
    case steps
    case activeEnergy
    case exerciseMinutes
    case workouts
    case sleep
    case restingHeartRate
    case hrv
    case weight
    case recoveryBaseline
    case remoteSync
}

/// Availability of a single Health Intelligence insight channel.
struct HealthInsightAvailability: Equatable, Sendable, Hashable {
    let kind: HealthInsightKind
    let isAvailable: Bool

    var isMissing: Bool { !isAvailable }
}

enum HealthInsightAvailabilityResolver {

    static func resolveAll(from input: HealthIntelligenceUIContext) -> [HealthInsightAvailability] {
        HealthInsightKind.allCases.map { kind in
            HealthInsightAvailability(
                kind: kind,
                isAvailable: isAvailable(kind, input: input)
            )
        }
    }

    static func missingKinds(from input: HealthIntelligenceUIContext) -> [HealthInsightKind] {
        resolveAll(from: input).compactMap { $0.isMissing ? $0.kind : nil }
    }

    static func missing(from input: HealthIntelligenceUIContext) -> [HealthInsightAvailability] {
        resolveAll(from: input).filter(\.isMissing)
    }

    // MARK: - Private

    private static func isAvailable(
        _ kind: HealthInsightKind,
        input: HealthIntelligenceUIContext
    ) -> Bool {
        let permission = input.availability?.permissionStatus
        let snapshot = input.snapshot
        let baseline = input.baseline

        switch kind {
        case .steps:
            return hasReadablePermission(.stepCount, permission: permission)
                || snapshot?.activity.steps != nil
                || baseline?.averageSteps7d != nil
        case .activeEnergy:
            return hasReadablePermission(.activeEnergyBurned, permission: permission)
                || snapshot?.activity.activeEnergyKcal != nil
                || baseline?.averageActiveEnergy7d != nil
        case .exerciseMinutes:
            return hasReadablePermission(.appleExerciseTime, permission: permission)
                || snapshot?.activity.exerciseMinutes != nil
        case .workouts:
            return hasReadablePermission(.workout, permission: permission)
                || snapshot?.workout?.hasWorkout == true
                || (baseline?.workoutDays28d ?? 0) > 0
        case .sleep:
            return hasReadablePermission(.sleepAnalysis, permission: permission)
                || baseline?.averageSleepDuration7d != nil
                || snapshot?.recovery.missingSignals.contains(.sleep) == false
        case .restingHeartRate:
            return hasReadablePermission(.restingHeartRate, permission: permission)
                || baseline?.averageRestingHeartRate28d != nil
                || snapshot?.recovery.missingSignals.contains(.restingHeartRate) == false
        case .hrv:
            return hasReadablePermission(.heartRateVariabilitySDNN, permission: permission)
                || baseline?.averageHRV28d != nil
                || snapshot?.recovery.missingSignals.contains(.hrv) == false
        case .weight:
            return hasReadablePermission(.bodyMass, permission: permission)
        case .recoveryBaseline:
            guard let baseline else { return false }
            return !baseline.missingSignals.contains(.sleep)
                || !baseline.missingSignals.contains(.hrv)
                || !baseline.missingSignals.contains(.restingHeartRate)
                || baseline.workoutDays28d != nil
        case .remoteSync:
            return input.isRemoteSyncCapabilityEnabled && input.isRemoteSyncUserEnabled
        }
    }

    private static func hasReadablePermission(
        _ signal: HealthSignalKind,
        permission: HealthPermissionStatus?
    ) -> Bool {
        permission?.access(for: signal).isReadable == true
    }
}

extension RecoveryMissingSignal {

    var insightKind: HealthInsightKind? {
        switch self {
        case .sleep:
            return .sleep
        case .restingHeartRate:
            return .restingHeartRate
        case .hrv:
            return .hrv
        case .workouts, .trainingLoad:
            return .workouts
        case .activity:
            return .steps
        }
    }
}

extension HealthBaselineSignal {

    var insightKind: HealthInsightKind {
        switch self {
        case .steps:
            return .steps
        case .activeEnergy:
            return .activeEnergy
        case .sleep:
            return .sleep
        case .restingHeartRate:
            return .restingHeartRate
        case .hrv:
            return .hrv
        case .workoutLoad:
            return .workouts
        }
    }
}
