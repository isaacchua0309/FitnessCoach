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

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else { return .unavailable }
        return Self.map(healthStore.authorizationStatus(for: HKObjectType.workoutType()))
    }

    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else { return .unavailable }

        do {
            try await healthStore.requestAuthorization(
                toShare: Self.writeTypes,
                read: Self.readTypes
            )
        } catch {
            return .sharingDenied
        }

        return workoutReadAuthorizationStatus()
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

        return types
    }

    static let writeTypes: Set<HKSampleType> = []

    private static func map(_ status: HKAuthorizationStatus) -> HealthTrainingAuthorizationStatus {
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

typealias SystemHealthKitTrainingAuthorization = UnavailableHealthKitTrainingAuthorization

#endif
