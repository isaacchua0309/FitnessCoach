//
//  HealthTrainingReaderFactory.swift
//  Fitness Coach
//
//  Composition-root factory for HealthKit readers (Infrastructure only).
//

import Foundation

enum HealthTrainingReaderFactory {

    static func makeWorkoutReader(
        healthKitManager: HealthKitManager = HealthKitManager()
    ) -> HealthKitWorkoutReading {
        #if canImport(HealthKit) && os(iOS)
        return SystemHealthKitWorkoutReader(healthKitManager: healthKitManager)
        #else
        return MockHealthKitWorkoutReader(workouts: [])
        #endif
    }

    static func makeStepReader(
        healthKitManager: HealthKitManager = HealthKitManager()
    ) -> HealthKitStepReading {
        #if canImport(HealthKit) && os(iOS)
        return SystemHealthKitStepReader(healthKitManager: healthKitManager)
        #else
        return MockHealthKitStepReader(stepCount: 0)
        #endif
    }
}
