//
//  HealthTrainingReaderFactory.swift
//  Fitness Coach
//
//  Composition-root factory for HealthKit readers (Infrastructure only).
//

import Foundation

enum HealthTrainingReaderFactory {

    static func makeWorkoutReader() -> HealthKitWorkoutReading {
        #if canImport(HealthKit) && os(iOS)
        return SystemHealthKitWorkoutReader()
        #else
        return MockHealthKitWorkoutReader(workouts: [])
        #endif
    }

    static func makeStepReader() -> HealthKitStepReading {
        #if canImport(HealthKit) && os(iOS)
        return SystemHealthKitStepReader()
        #else
        return MockHealthKitStepReader(stepCount: 0)
        #endif
    }
}
