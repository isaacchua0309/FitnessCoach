//
//  HealthKitReadTypeRegistry.swift
//  Fitness Coach
//
//  Forma — Single source of truth for HealthKit read types (Health Intelligence).
//

import Foundation

#if canImport(HealthKit)
import HealthKit

enum HealthKitReadTypeRegistry {

    static let writeTypes: Set<HKSampleType> = []

    /// Signals included in `requestAuthorization` by default.
    static let defaultRequestedSignals: [HealthSignalKind] = HealthSignalKind.required

    /// Declared for future use; not requested unless explicitly enabled.
    static let futureOptionalSignals: [HealthSignalKind] = HealthSignalKind.futureOptional

    static func requestedSignals(includingFutureTypes: Bool) -> [HealthSignalKind] {
        includingFutureTypes ? defaultRequestedSignals + futureOptionalSignals : defaultRequestedSignals
    }

    static func hkObjectType(for signal: HealthSignalKind) -> HKObjectType? {
        switch signal {
        case .workout:
            return HKObjectType.workoutType()
        case .sleepAnalysis:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .stepCount:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .activeEnergyBurned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .appleExerciseTime:
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .restingHeartRate:
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
        case .heartRateVariabilitySDNN:
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .bodyMass:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .walkingHeartRateAverage:
            return HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .vo2Max:
            return HKQuantityType.quantityType(forIdentifier: .vo2Max)
        case .distanceWalkingRunning:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .appleStandTime:
            return HKQuantityType.quantityType(forIdentifier: .appleStandTime)
        }
    }

    static func hkSampleType(for signal: HealthSignalKind) -> HKSampleType? {
        hkObjectType(for: signal) as? HKSampleType
    }

    static func readTypes(for signals: [HealthSignalKind]) -> Set<HKObjectType> {
        Set(signals.compactMap { hkObjectType(for: $0) })
    }

    static var defaultReadTypes: Set<HKObjectType> {
        readTypes(for: defaultRequestedSignals)
    }

    static func readTypeLabels(for signals: [HealthSignalKind]) -> [String] {
        signals.compactMap { hkObjectType(for: $0)?.identifier }.sorted()
    }
}

#else

enum HealthKitReadTypeRegistry {

    static let defaultRequestedSignals: [HealthSignalKind] = HealthSignalKind.required
    static let futureOptionalSignals: [HealthSignalKind] = HealthSignalKind.futureOptional

    static func requestedSignals(includingFutureTypes: Bool) -> [HealthSignalKind] {
        includingFutureTypes ? defaultRequestedSignals + futureOptionalSignals : defaultRequestedSignals
    }
}

#endif
