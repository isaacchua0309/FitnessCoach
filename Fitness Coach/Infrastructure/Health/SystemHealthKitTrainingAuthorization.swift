//
//  SystemHealthKitTrainingAuthorization.swift
//  Fitness Coach
//
//  Forma — Read-only HealthKit authorization via HealthKitManager.
//

import Foundation

#if canImport(HealthKit) && os(iOS)

final class SystemHealthKitTrainingAuthorization: HealthKitTrainingAuthorizing, @unchecked Sendable {

    private let healthKitManager: HealthKitManager

    nonisolated init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    var isHealthDataAvailable: Bool {
        healthKitManager.isHealthDataAvailable
    }

    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("workoutReadAuthorizationStatus: Health data unavailable")
            return .unavailable
        }

        let status = healthKitManager.legacyWorkoutShareAuthorizationStatus()
        HealthTrainingDebugLogger.logAuthorizationStatus(status, context: "workoutReadAuthorizationStatus.legacyShareStatus")
        HealthTrainingDebugLogger.event(
            "Note: authorizationStatus(for:) reflects write/share permission, not read access — use resolveWorkoutReadAccess()"
        )
        return status
    }

    func resolveWorkoutReadAccess() async -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("resolveWorkoutReadAccess: Health data unavailable")
            return .unavailable
        }

        let permissionStatus = await healthKitManager.getAuthorizationStatus()
        let mapped = Self.mapTrainingStatus(from: permissionStatus)
        HealthTrainingDebugLogger.logAuthorizationStatus(mapped, context: "resolveWorkoutReadAccess")
        return mapped
    }

    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("requestReadAuthorization: Health data unavailable")
            return .unavailable
        }

        HealthTrainingDebugLogger.event(
            "requestReadAuthorization starting",
            fields: [
                "readTypeCount": String(HealthKitReadTypeRegistry.defaultRequestedSignals.count),
                "writeTypeCount": "0",
                "readTypes": HealthKitReadTypeRegistry.readTypeLabels(
                    for: HealthKitReadTypeRegistry.defaultRequestedSignals
                ).joined(separator: ",")
            ]
        )

        do {
            let permissionStatus = try await healthKitManager.requestAuthorization()
            let mapped = Self.mapTrainingStatus(from: permissionStatus)
            HealthTrainingDebugLogger.logAuthorizationStatus(mapped, context: "requestReadAuthorization.resolvedReadAccess")
            return mapped
        } catch {
            HealthTrainingDebugLogger.error(
                "requestReadAuthorization failed",
                underlying: error
            )
            return .sharingDenied
        }
    }

    // MARK: - Private

    private static func mapTrainingStatus(
        from permissionStatus: HealthPermissionStatus
    ) -> HealthTrainingAuthorizationStatus {
        if permissionStatus.access(for: .workout).isReadable {
            return .sharingAuthorized
        }
        if permissionStatus.access(for: .stepCount).isReadable {
            return .sharingAuthorized
        }

        switch permissionStatus.access(for: .workout) {
        case .denied:
            return .sharingDenied
        case .notDetermined:
            return .notDetermined
        case .unavailable:
            return .unavailable
        case .unknown, .available:
            return .notDetermined
        }
    }
}

#else

typealias SystemHealthKitTrainingAuthorization = UnavailableHealthKitTrainingAuthorization

#endif
