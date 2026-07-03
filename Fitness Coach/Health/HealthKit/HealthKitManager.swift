//
//  HealthKitManager.swift
//  Fitness Coach
//
//  Forma — Low-level HealthKit access for Health Intelligence (isolated import boundary).
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthKitManagerError: Error, Equatable, Sendable {
    case unavailable
    case authorizationDenied
    case queryFailed
}

protocol HealthKitManaging: Sendable {
    var isHealthDataAvailable: Bool { get }
    func resolvePermissionStatus(
        includingFutureTypes: Bool
    ) async -> HealthPermissionStatus
    func requestAuthorization(
        includingFutureTypes: Bool
    ) async throws -> HealthPermissionStatus
    func fetchSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthNormalizedSample]
}

#if canImport(HealthKit) && os(iOS)

final class HealthKitManager: HealthKitManaging, @unchecked Sendable {

    private let healthStore: HKHealthStore

    nonisolated init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func resolvePermissionStatus(
        includingFutureTypes: Bool = false
    ) async -> HealthPermissionStatus {
        guard isHealthDataAvailable else {
            HealthPermissionLogger.warn("resolvePermissionStatus: Health data unavailable")
            return .unavailable()
        }

        let signals = HealthKitReadTypeRegistry.requestedSignals(
            includingFutureTypes: includingFutureTypes
        )
        let requestStatus = await fetchAuthorizationRequestStatus(for: signals)

        HealthPermissionLogger.event(
            "resolvePermissionStatus",
            fields: [
                "requestStatus": Self.requestStatusLabel(requestStatus),
                "signalCount": String(signals.count),
                "includingFutureTypes": String(includingFutureTypes)
            ]
        )

        switch requestStatus {
        case .shouldRequest:
            return Self.uniformNotDetermined(signals: signals)
        case .unnecessary, .unknown:
            return await probeSignalAccess(for: signals)
        @unknown default:
            return await probeSignalAccess(for: signals)
        }
    }

    func requestAuthorization(
        includingFutureTypes: Bool = false
    ) async throws -> HealthPermissionStatus {
        guard isHealthDataAvailable else {
            HealthPermissionLogger.warn("requestAuthorization: Health data unavailable")
            throw HealthKitManagerError.unavailable
        }

        let signals = HealthKitReadTypeRegistry.requestedSignals(
            includingFutureTypes: includingFutureTypes
        )
        let readTypes = HealthKitReadTypeRegistry.readTypes(for: signals)

        guard !readTypes.isEmpty else {
            HealthPermissionLogger.warn("requestAuthorization: No readable types resolved")
            throw HealthKitManagerError.unavailable
        }

        HealthPermissionLogger.event(
            "requestAuthorization starting",
            fields: [
                "readTypeCount": String(readTypes.count),
                "writeTypeCount": "0",
                "readTypes": HealthKitReadTypeRegistry.readTypeLabels(for: signals).joined(separator: ","),
                "includingFutureTypes": String(includingFutureTypes)
            ]
        )

        do {
            try await healthStore.requestAuthorization(
                toShare: HealthKitReadTypeRegistry.writeTypes,
                read: readTypes
            )
            HealthPermissionLogger.event("requestAuthorization completed without error")
        } catch {
            HealthPermissionLogger.authorizationFailure(
                context: "requestAuthorization",
                underlying: error
            )
            throw HealthKitManagerError.authorizationDenied
        }

        let resolved = await probeSignalAccess(for: signals)
        HealthPermissionLogger.logResolvedStatus(resolved, context: "requestAuthorization")
        return resolved
    }

    func fetchSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthNormalizedSample] {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.unavailable
        }
        _ = (startDate, endDate, healthStore)
        // TODO: Issue anchored/statistics queries and map HK samples to HealthNormalizedSample.
        return []
    }

    // MARK: - Private

    private func fetchAuthorizationRequestStatus(
        for signals: [HealthSignalKind]
    ) async -> HKAuthorizationRequestStatus {
        let readTypes = HealthKitReadTypeRegistry.readTypes(for: signals)
        return await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: HealthKitReadTypeRegistry.writeTypes,
                read: readTypes
            ) { status, error in
                if let error {
                    HealthPermissionLogger.authorizationFailure(
                        context: "getRequestStatusForAuthorization",
                        underlying: error
                    )
                }
                continuation.resume(returning: status)
            }
        }
    }

    private func probeSignalAccess(for signals: [HealthSignalKind]) async -> HealthPermissionStatus {
        var access: [HealthSignalKind: HealthSignalAccess] = [:]
        access.reserveCapacity(signals.count)

        for signal in signals {
            access[signal] = await probeAccess(for: signal)
        }

        for signal in HealthSignalKind.futureOptional where access[signal] == nil {
            access[signal] = .unavailable
        }

        let status = HealthPermissionStatus(
            isHealthDataAvailable: true,
            signalAccess: access,
            resolvedAt: Date()
        )
        HealthPermissionLogger.logResolvedStatus(status, context: "probeSignalAccess")
        return status
    }

    private func probeAccess(for signal: HealthSignalKind) async -> HealthSignalAccess {
        guard let sampleType = HealthKitReadTypeRegistry.hkSampleType(for: signal) else {
            HealthPermissionLogger.warn(
                "Signal type unavailable on device",
                fields: ["signal": signal.rawValue]
            )
            return .unavailable
        }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, _, error in
                if let error {
                    continuation.resume(returning: Self.mapProbeError(error, signal: signal))
                    return
                }
                continuation.resume(returning: .available)
            }
            healthStore.execute(query)
        }
    }

    private static func mapProbeError(
        _ error: Error,
        signal: HealthSignalKind
    ) -> HealthSignalAccess {
        if let hkError = error as? HKError {
            HealthPermissionLogger.authorizationFailure(
                context: "probeAccess",
                signal: signal,
                underlying: hkError
            )
            switch hkError.code {
            case .errorAuthorizationDenied:
                return .denied
            case .errorAuthorizationNotDetermined:
                return .notDetermined
            default:
                return .unknown
            }
        }

        let nsError = error as NSError
        if nsError.domain == HKError.errorDomain,
           let code = HKError.Code(rawValue: nsError.code) {
            switch code {
            case .errorAuthorizationDenied:
                return .denied
            case .errorAuthorizationNotDetermined:
                return .notDetermined
            default:
                return .unknown
            }
        }

        HealthPermissionLogger.authorizationFailure(
            context: "probeAccess.nonHKError",
            signal: signal,
            underlying: error
        )
        return .unknown
    }

    private static func uniformNotDetermined(
        signals: [HealthSignalKind]
    ) -> HealthPermissionStatus {
        .uniform(
            .notDetermined,
            isHealthDataAvailable: true,
            signals: signals
        )
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

struct HealthKitManager: HealthKitManaging, Sendable {

    var isHealthDataAvailable: Bool { false }

    func resolvePermissionStatus(
        includingFutureTypes: Bool = false
    ) async -> HealthPermissionStatus {
        _ = includingFutureTypes
        return .unavailable()
    }

    func requestAuthorization(
        includingFutureTypes: Bool = false
    ) async throws -> HealthPermissionStatus {
        _ = includingFutureTypes
        throw HealthKitManagerError.unavailable
    }

    func fetchSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthNormalizedSample] {
        _ = (startDate, endDate)
        throw HealthKitManagerError.unavailable
    }
}

#endif
