//
//  HealthActivityQueryService.swift
//  Fitness Coach
//
//  Application-layer queries for Apple Health workouts and steps.
//
//  Primary path routes through HealthDataRepository when repositoryReadRoutingEnabled
//  (default). Direct HealthKit reader fallback remains for flag-off rollback only.
//

import Foundation

struct HealthActivityQueryService: Sendable {

    let workoutReader: HealthKitWorkoutReading
    let stepReader: HealthKitStepReading
    let healthDataRepository: (any HealthDataRepositorying)?
    let repositoryReadRoutingEnabled: Bool

    init(
        workoutReader: HealthKitWorkoutReading,
        stepReader: HealthKitStepReading,
        healthDataRepository: (any HealthDataRepositorying)? = nil,
        repositoryReadRoutingEnabled: Bool = HealthIntelligenceFeatureFlags.isRepositoryReadRoutingEnabled
    ) {
        self.workoutReader = workoutReader
        self.stepReader = stepReader
        self.healthDataRepository = healthDataRepository
        self.repositoryReadRoutingEnabled = repositoryReadRoutingEnabled
    }

    func workouts(
        from startDate: Date,
        to endDate: Date
    ) async -> [HealthWorkoutRecord] {
        if repositoryReadRoutingEnabled, let healthDataRepository {
            let workouts = await healthDataRepository.getWorkouts(from: startDate, to: endDate)
            return workouts.map(\.asHealthWorkoutRecord)
        }

        do {
            return try await workoutReader.fetchWorkouts(from: startDate, to: endDate)
        } catch {
            // Deprecated fallback path — remove when isRepositoryReadRoutingEnabled flag is retired.
            let fields: [String: String] = [
                "start": ISO8601DateFormatter().string(from: startDate),
                "end": ISO8601DateFormatter().string(from: endDate),
                "optionalAccessFailure": String(HealthKitOptionalAccessPolicy.isOptionalAccessFailure(error))
            ]
            HealthTrainingDebugLogger.error(
                "workouts query degraded to empty",
                fields: fields,
                underlying: error
            )
            return []
        }
    }

    func workoutCountToday(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async -> Int {
        await dailyTrainingActivity(on: date, calendar: calendar).workoutCount
    }

    func workoutCountThisWeek(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async -> Int {
        let todayStart = calendar.startOfDay(for: date)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? date
        let workouts = await workouts(from: weekStart, to: dayEnd)
        return workouts.count
    }

    func dailyTrainingActivity(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async -> DailyTrainingActivity {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let dayWorkouts = await workouts(from: dayStart, to: dayEnd)
        return DailyTrainingActivity(workouts: dayWorkouts)
    }

    func workoutDayStarts(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async -> Set<Date> {
        let records = await workouts(from: startDate, to: endDate)
        return Set(records.map { calendar.startOfDay(for: $0.startDate) })
    }

    func stepsToday(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        if repositoryReadRoutingEnabled, let healthDataRepository {
            let metrics = await healthDataRepository.getDailyMetrics(for: date, calendar: calendar)
            return metrics.steps
        }

        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        return try await stepReader.fetchStepCount(from: dayStart, to: dayEnd)
    }
}
