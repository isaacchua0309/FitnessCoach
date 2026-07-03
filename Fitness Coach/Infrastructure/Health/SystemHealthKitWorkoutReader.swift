//
//  SystemHealthKitWorkoutReader.swift
//  Fitness Coach
//
//  Forma — Reads workout samples from Apple Health via HealthKitManager.
//

import Foundation

#if canImport(HealthKit) && os(iOS)

final class SystemHealthKitWorkoutReader: HealthKitWorkoutReading, @unchecked Sendable {

    private let healthKitManager: HealthKitManager

    nonisolated init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        guard healthKitManager.isHealthDataAvailable else {
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

        let workouts = try await healthKitManager.fetchWorkouts(from: startDate, to: endDate)
        let records = workouts.map(Self.mapToHealthWorkoutRecord)

        HealthTrainingDebugLogger.event(
            "fetchWorkouts completed",
            fields: [
                "workoutCount": String(records.count)
            ]
        )

        return records
    }

    private static func mapToHealthWorkoutRecord(_ workout: HealthFetchedWorkout) -> HealthWorkoutRecord {
        HealthWorkoutRecord(
            id: workout.id,
            activityName: workout.activityTypeName,
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: workout.durationMinutes,
            activeCalories: workout.activeCaloriesKcal.map { Int($0.rounded()) }
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
