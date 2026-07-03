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
    func requestAuthorization() async throws
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

    func requestAuthorization() async throws {
        // TODO: Request read types required by Health Intelligence (workouts, activity, recovery signals).
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.unavailable
        }

        let readTypes = Self.defaultReadTypes
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthNormalizedSample] {
        // TODO: Issue anchored/statistics queries and map HK samples to HealthNormalizedSample.
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.unavailable
        }
        _ = (startDate, endDate, healthStore)
        return []
    }

    // MARK: - Private

    private static var defaultReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        return types
    }
}

#else

struct HealthKitManager: HealthKitManaging, Sendable {

    var isHealthDataAvailable: Bool { false }

    func requestAuthorization() async throws {
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
