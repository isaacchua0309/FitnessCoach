//
//  SystemHealthKitWorkoutReader.swift
//  Fitness Coach
//
//  Forma — Reads workout samples from Apple Health (read-only).
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(HealthKit) && os(iOS)

final class SystemHealthKitWorkoutReader: HealthKitWorkoutReading, @unchecked Sendable {

    private let healthStore: HKHealthStore

    nonisolated init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        guard HKHealthStore.isHealthDataAvailable() else {
            HealthTrainingDebugLogger.warn("fetchWorkouts aborted: Health data unavailable")
            return []
        }

        HealthTrainingDebugLogger.event(
            "fetchWorkouts started",
            fields: [
                "start": ISO8601DateFormatter().string(from: startDate),
                "end": ISO8601DateFormatter().string(from: endDate)
            ]
        )

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    HealthTrainingDebugLogger.error(
                        "fetchWorkouts query failed",
                        fields: [
                            "start": ISO8601DateFormatter().string(from: startDate),
                            "end": ISO8601DateFormatter().string(from: endDate)
                        ],
                        underlying: error
                    )
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }

        let workouts: [HealthWorkoutRecord] = samples.compactMap { sample -> HealthWorkoutRecord? in
            guard let workout = sample as? HKWorkout else { return nil }
            return Self.map(workout)
        }

        HealthTrainingDebugLogger.event(
            "fetchWorkouts completed",
            fields: [
                "sampleCount": String(samples.count),
                "workoutCount": String(workouts.count)
            ]
        )

        return workouts
    }

    private static func map(_ workout: HKWorkout) -> HealthWorkoutRecord {
        let durationMinutes = max(Int((workout.duration / 60.0).rounded()), 1)
        let calories: Int?
        if #available(iOS 18.0, *) {
            let energyType = HKQuantityType(.activeEnergyBurned)
            if let sum = workout.statistics(for: energyType)?.sumQuantity() {
                calories = Int(sum.doubleValue(for: .kilocalorie()).rounded())
            } else {
                calories = nil
            }
        } else if let quantity = workout.totalEnergyBurned {
            calories = Int(quantity.doubleValue(for: .kilocalorie()).rounded())
        } else {
            calories = nil
        }

        return HealthWorkoutRecord(
            id: workout.uuid,
            activityName: HealthWorkoutActivityFormatter.displayName(for: workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: durationMinutes,
            activeCalories: calories
        )
    }
}

#else

struct SystemHealthKitWorkoutReader: HealthKitWorkoutReading, Sendable {
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        []
    }
}

#endif
