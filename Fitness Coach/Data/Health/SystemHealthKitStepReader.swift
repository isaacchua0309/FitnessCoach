//
//  SystemHealthKitStepReader.swift
//  Fitness Coach
//
//  Forma — Reads step count samples from Apple Health (read-only).
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(HealthKit) && os(iOS)

final class SystemHealthKitStepReader: HealthKitStepReading, @unchecked Sendable {

    private let healthStore: HKHealthStore

    nonisolated init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: max(Int(steps.rounded()), 0))
            }
            healthStore.execute(query)
        }
    }
}

#else

struct SystemHealthKitStepReader: HealthKitStepReading, Sendable {
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        0
    }
}

#endif
