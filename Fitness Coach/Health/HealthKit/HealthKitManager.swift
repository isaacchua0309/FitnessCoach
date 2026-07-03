//
//  HealthKitManager.swift
//  Fitness Coach
//
//  Forma — Sole HealthKit I/O class for Health Intelligence.
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
    func requestAuthorization(includingFutureTypes: Bool) async throws -> HealthPermissionStatus
    func getAuthorizationStatus(includingFutureTypes: Bool) async -> HealthPermissionStatus
    func fetchDailyMetrics(for date: Date, calendar: Calendar) async throws -> HealthDailyMetrics
    func fetchDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async throws -> [HealthDailyMetrics]
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthFetchedWorkout]
    func fetchSleepRecords(from startDate: Date, to endDate: Date) async throws -> [HealthSleepRecord]
    func fetchHeartMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthHeartMetric]
    func fetchBodyMassRecords(from startDate: Date, to endDate: Date) async throws -> [HealthBodyMassRecord]
}

extension HealthKitManaging {
    func requestAuthorization() async throws -> HealthPermissionStatus {
        try await requestAuthorization(includingFutureTypes: false)
    }

    func getAuthorizationStatus() async -> HealthPermissionStatus {
        await getAuthorizationStatus(includingFutureTypes: false)
    }

    func fetchDailyMetrics(for date: Date) async throws -> HealthDailyMetrics {
        try await fetchDailyMetrics(for: date, calendar: .current)
    }

    func fetchDailyMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthDailyMetrics] {
        try await fetchDailyMetrics(from: startDate, to: endDate, calendar: .current)
    }
}

#if canImport(HealthKit) && os(iOS)

final class HealthKitManager: HealthKitManaging, @unchecked Sendable {

    let healthStore: HKHealthStore

    nonisolated init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func getAuthorizationStatus(
        includingFutureTypes: Bool = false
    ) async -> HealthPermissionStatus {
        guard isHealthDataAvailable else {
            HealthPermissionLogger.warn("getAuthorizationStatus: Health data unavailable")
            return .unavailable()
        }

        let signals = HealthKitReadTypeRegistry.requestedSignals(
            includingFutureTypes: includingFutureTypes
        )
        let requestStatus = await fetchAuthorizationRequestStatus(for: signals)

        HealthPermissionLogger.event(
            "getAuthorizationStatus",
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

    /// Legacy synchronous share-status for workout type (unreliable for read access).
    func legacyWorkoutShareAuthorizationStatus() -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else {
            return .unavailable
        }
        return Self.mapLegacyShareStatus(
            healthStore.authorizationStatus(for: HKObjectType.workoutType())
        )
    }

    // MARK: - Authorization internals

    func fetchAuthorizationRequestStatus(
        for signals: [HealthSignalKind]
    ) async -> HKAuthorizationRequestStatus {
        let readTypes = HealthKitReadTypeRegistry.readTypes(for: signals)
        return await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()
            healthStore.getRequestStatusForAuthorization(
                toShare: HealthKitReadTypeRegistry.writeTypes,
                read: readTypes
            ) { status, error in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
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

    func probeSignalAccess(for signals: [HealthSignalKind]) async -> HealthPermissionStatus {
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

    func probeAccess(for signal: HealthSignalKind) async -> HealthSignalAccess {
        guard let sampleType = HealthKitReadTypeRegistry.hkSampleType(for: signal) else {
            HealthPermissionLogger.warn(
                "Signal type unavailable on device",
                fields: ["signal": signal.rawValue]
            )
            return .unavailable
        }

        do {
            _ = try await executeSampleQuery(
                sampleType: sampleType,
                startDate: nil,
                endDate: nil,
                limit: 1,
                sortDescriptors: nil
            )
            return .available
        } catch let error as HealthKitManagerError {
            switch error {
            case .authorizationDenied:
                return .denied
            case .unavailable:
                return .unavailable
            case .queryFailed:
                return .unknown
            }
        } catch {
            return Self.mapProbeError(error, signal: signal)
        }
    }

    // MARK: - Query execution

    func executeStatisticsSum(
        quantityType: HKQuantityType,
        startDate: Date,
        endDate: Date,
        unit: HKUnit
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true

                if let error {
                    continuation.resume(throwing: Self.mapQueryError(error))
                    return
                }

                guard let quantity = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    func executeStatisticsCollection(
        quantityType: HKQuantityType,
        startDate: Date,
        endDate: Date,
        anchorDate: Date,
        interval: DateComponents,
        unit: HKUnit
    ) async throws -> [(Date, Double)] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true

                if let error {
                    continuation.resume(throwing: Self.mapQueryError(error))
                    return
                }

                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }

                var values: [(Date, Double)] = []
                collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    guard let quantity = statistics.sumQuantity() else { return }
                    let value = quantity.doubleValue(for: unit)
                    if value > 0 {
                        values.append((statistics.startDate, value))
                    }
                }
                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    func executeSampleQuery(
        sampleType: HKSampleType,
        startDate: Date?,
        endDate: Date?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        let predicate: NSPredicate?
        if let startDate, let endDate {
            predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
        } else {
            predicate = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true

                if let error {
                    continuation.resume(throwing: Self.mapQueryError(error))
                    return
                }

                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }
    }

    func quantityType(for signal: HealthSignalKind) -> HKQuantityType? {
        HealthKitReadTypeRegistry.hkObjectType(for: signal) as? HKQuantityType
    }

    // MARK: - Error mapping

    static func mapQueryError(_ error: Error) -> HealthKitManagerError {
        if let hkError = error as? HKError {
            switch hkError.code {
            case .errorAuthorizationDenied, .errorAuthorizationNotDetermined:
                return .authorizationDenied
            default:
                return .queryFailed
            }
        }

        let nsError = error as NSError
        if nsError.domain == HKError.errorDomain,
           let code = HKError.Code(rawValue: nsError.code) {
            switch code {
            case .errorAuthorizationDenied, .errorAuthorizationNotDetermined:
                return .authorizationDenied
            default:
                return .queryFailed
            }
        }

        return .queryFailed
    }

    static func mapProbeError(
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

    static func uniformNotDetermined(
        signals: [HealthSignalKind]
    ) -> HealthPermissionStatus {
        .uniform(
            .notDetermined,
            isHealthDataAvailable: true,
            signals: signals
        )
    }

    static func requestStatusLabel(_ status: HKAuthorizationRequestStatus) -> String {
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

    static func mapLegacyShareStatus(_ status: HKAuthorizationStatus) -> HealthTrainingAuthorizationStatus {
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
}

#else

struct HealthKitManager: HealthKitManaging, Sendable {

    var isHealthDataAvailable: Bool { false }

    func getAuthorizationStatus(
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

    func fetchDailyMetrics(for date: Date, calendar: Calendar = .current) async throws -> HealthDailyMetrics {
        _ = (date, calendar)
        throw HealthKitManagerError.unavailable
    }

    func fetchDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async throws -> [HealthDailyMetrics] {
        _ = (startDate, endDate, calendar)
        throw HealthKitManagerError.unavailable
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthFetchedWorkout] {
        _ = (startDate, endDate)
        throw HealthKitManagerError.unavailable
    }

    func fetchSleepRecords(from startDate: Date, to endDate: Date) async throws -> [HealthSleepRecord] {
        _ = (startDate, endDate)
        throw HealthKitManagerError.unavailable
    }

    func fetchHeartMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthHeartMetric] {
        _ = (startDate, endDate)
        throw HealthKitManagerError.unavailable
    }

    func fetchBodyMassRecords(from startDate: Date, to endDate: Date) async throws -> [HealthBodyMassRecord] {
        _ = (startDate, endDate)
        throw HealthKitManagerError.unavailable
    }
}

#endif
