//
//  SystemHealthKitTrainingAuthorization.swift
//  Fitness Coach
//
//  Forma — Read-only HealthKit authorization for Training Insights (Stage 4).
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(HealthKit) && os(iOS)

final class SystemHealthKitTrainingAuthorization: HealthKitTrainingAuthorizing, @unchecked Sendable {

    private let healthStore: HKHealthStore

    nonisolated init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("workoutReadAuthorizationStatus: Health data unavailable")
            return .unavailable
        }

        let hkStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        HealthTrainingDebugLogger.logHKAuthorizationStatus(
            hkStatus,
            context: "workoutReadAuthorizationStatus.legacyShareStatus"
        )
        HealthTrainingDebugLogger.event(
            "Note: authorizationStatus(for:) reflects write/share permission, not read access — use resolveWorkoutReadAccess()"
        )
        return Self.mapLegacyShareStatus(hkStatus)
    }

    func resolveWorkoutReadAccess() async -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("resolveWorkoutReadAccess: Health data unavailable")
            return .unavailable
        }

        let requestStatus = await fetchAuthorizationRequestStatus()
        HealthTrainingDebugLogger.event(
            "getRequestStatusForAuthorization",
            fields: ["requestStatus": Self.requestStatusLabel(requestStatus)]
        )

        switch requestStatus {
        case .shouldRequest:
            return .notDetermined
        case .unnecessary, .unknown:
            return await probeReadAccess()
        @unknown default:
            return await probeReadAccess()
        }
    }

    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("requestReadAuthorization: Health data unavailable")
            return .unavailable
        }

        let requestStatus = await fetchAuthorizationRequestStatus()
        HealthTrainingDebugLogger.event(
            "requestReadAuthorization starting",
            fields: ["requestStatusBefore": Self.requestStatusLabel(requestStatus)]
        )

        HealthTrainingDebugLogger.event(
            "Calling HKHealthStore.requestAuthorization",
            fields: [
                "readTypeCount": String(Self.readTypes.count),
                "writeTypeCount": String(Self.writeTypes.count),
                "readTypes": Self.readTypeLabels.joined(separator: ",")
            ]
        )

        do {
            try await healthStore.requestAuthorization(
                toShare: Self.writeTypes,
                read: Self.readTypes
            )
            HealthTrainingDebugLogger.event("HKHealthStore.requestAuthorization completed without error")
        } catch {
            HealthTrainingDebugLogger.error(
                "HKHealthStore.requestAuthorization threw",
                underlying: error
            )
            return .sharingDenied
        }

        let resolved = await probeReadAccess()
        let legacyStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        HealthTrainingDebugLogger.logHKAuthorizationStatus(
            legacyStatus,
            context: "requestReadAuthorization.legacyShareStatusAfterRequest"
        )
        HealthTrainingDebugLogger.logAuthorizationStatus(
            resolved,
            context: "requestReadAuthorization.resolvedReadAccess"
        )
        return resolved
    }

    // MARK: - HealthKit types

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]

        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }

        return types
    }

    static let writeTypes: Set<HKSampleType> = []

    static var readTypeLabels: [String] {
        readTypes.map { $0.identifier }.sorted()
    }

    // MARK: - Private

    private func fetchAuthorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: Self.writeTypes,
                read: Self.readTypes
            ) { status, error in
                if let error {
                    HealthTrainingDebugLogger.error(
                        "getRequestStatusForAuthorization failed",
                        underlying: error
                    )
                }
                continuation.resume(returning: status)
            }
        }
    }

    private func probeReadAccess() async -> HealthTrainingAuthorizationStatus {
        await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    if let hkError = error as? HKError {
                        HealthTrainingDebugLogger.error(
                            "Read access probe failed",
                            fields: ["hkErrorCode": String(describing: hkError.code)],
                            underlying: error
                        )
                        switch hkError.code {
                        case .errorAuthorizationDenied:
                            continuation.resume(returning: .sharingDenied)
                        case .errorAuthorizationNotDetermined:
                            continuation.resume(returning: .notDetermined)
                        default:
                            continuation.resume(returning: .sharingAuthorized)
                        }
                    } else {
                        HealthTrainingDebugLogger.error(
                            "Read access probe failed with non-HK error",
                            underlying: error
                        )
                        continuation.resume(returning: .sharingAuthorized)
                    }
                    return
                }

                HealthTrainingDebugLogger.event(
                    "Read access probe succeeded",
                    fields: ["sampleCount": String(samples?.count ?? 0)]
                )
                HealthTrainingDebugLogger.event(
                    "Connected: verify permissions in Health app → Apps → Forma (not Settings → Forma)"
                )
                continuation.resume(returning: .sharingAuthorized)
            }
            healthStore.execute(query)
        }
    }

    private static func mapLegacyShareStatus(_ status: HKAuthorizationStatus) -> HealthTrainingAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .sharingDenied
        case .sharingAuthorized:
            return .sharingAuthorized
        @unknown default:
            return .notDetermined
        }
    }

    private static func requestStatusLabel(_ status: HKAuthorizationRequestStatus) -> String {
        switch status {
        case .unknown:
            return "unknown"
        case .shouldRequest:
            return "shouldRequest"
        case .unnecessary:
            return "unnecessary"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }
}

#else

typealias SystemHealthKitTrainingAuthorization = UnavailableHealthKitTrainingAuthorization

#endif
