//
//  SystemHealthKitStepReader.swift
//  Fitness Coach
//
//  Forma — Reads step count samples from Apple Health via HealthKitManager.
//

import Foundation

#if canImport(HealthKit) && os(iOS)

final class SystemHealthKitStepReader: HealthKitStepReading, @unchecked Sendable {

    private let healthKitManager: HealthKitManager

    nonisolated init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        guard healthKitManager.isHealthDataAvailable else {
            return 0
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: startDate)

        do {
            let metrics = try await healthKitManager.fetchDailyMetrics(for: dayStart, calendar: calendar)
            return metrics.steps ?? 0
        } catch HealthKitManagerError.unavailable {
            return 0
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
