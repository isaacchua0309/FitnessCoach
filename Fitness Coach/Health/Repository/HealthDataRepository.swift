//
//  HealthDataRepository.swift
//  Fitness Coach
//
//  Forma — Repository boundary for normalized Health Intelligence data.
//

import Foundation

enum HealthDataRepositoryError: Error, Equatable, Sendable {
    case unavailable
    case permissionDenied
    case fetchFailed
}

protocol HealthDataRepositorying: Sendable {
    func normalizedSamples(
        for date: Date,
        calendar: Calendar
    ) async throws -> [HealthNormalizedSample]
}

struct HealthDataRepository: HealthDataRepositorying {

    private let healthKitManager: any HealthKitManaging
    private let normalizer: any HealthSampleNormalizing
    private let cacheStore: any HealthCacheStoring

    init(
        healthKitManager: any HealthKitManaging = HealthKitManager(),
        normalizer: any HealthSampleNormalizing = HealthSampleNormalizer(),
        cacheStore: any HealthCacheStoring = HealthCacheStore()
    ) {
        self.healthKitManager = healthKitManager
        self.normalizer = normalizer
        self.cacheStore = cacheStore
    }

    func normalizedSamples(
        for date: Date,
        calendar: Calendar = .current
    ) async throws -> [HealthNormalizedSample] {
        if let cached = cacheStore.entry(for: date, calendar: calendar) {
            return cached.samples
        }

        guard healthKitManager.isHealthDataAvailable else {
            throw HealthDataRepositoryError.unavailable
        }

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw HealthDataRepositoryError.fetchFailed
        }

        do {
            let rawSamples = try await loadNormalizedSamples(
                dayStart: dayStart,
                dayEnd: dayEnd,
                calendar: calendar
            )
            let normalized = normalizer.deduplicate(samples: rawSamples)
            cacheStore.store(
                HealthCacheEntry(date: dayStart, samples: normalized, cachedAt: Date()),
                calendar: calendar
            )
            return normalized
        } catch HealthKitManagerError.unavailable {
            throw HealthDataRepositoryError.unavailable
        } catch HealthKitManagerError.authorizationDenied {
            throw HealthDataRepositoryError.permissionDenied
        } catch {
            throw HealthDataRepositoryError.fetchFailed
        }
    }

    // MARK: - Private

    private func loadNormalizedSamples(
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) async throws -> [HealthNormalizedSample] {
        var samples: [HealthNormalizedSample] = []

        let metrics = try await healthKitManager.fetchDailyMetrics(for: dayStart, calendar: calendar)
        if let steps = metrics.steps {
            samples.append(
                HealthNormalizedSample(
                    kind: .stepCount,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: Double(steps),
                    unitSymbol: HealthUnitSymbol.count
                )
            )
        }
        if let energy = metrics.activeEnergyKcal {
            samples.append(
                HealthNormalizedSample(
                    kind: .activeEnergy,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: energy,
                    unitSymbol: HealthUnitSymbol.kilocalorie
                )
            )
        }
        if let exercise = metrics.exerciseMinutes {
            samples.append(
                HealthNormalizedSample(
                    kind: .exerciseTime,
                    startDate: dayStart,
                    endDate: dayEnd,
                    value: exercise,
                    unitSymbol: HealthUnitSymbol.minutes
                )
            )
        }

        let workouts = try await healthKitManager.fetchWorkouts(from: dayStart, to: dayEnd)
        for workout in workouts {
            samples.append(
                HealthNormalizedSample(
                    id: workout.id,
                    kind: .workout,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    value: Double(workout.durationMinutes),
                    unitSymbol: HealthUnitSymbol.minutes,
                    sourceBundleIdentifier: workout.sourceName
                )
            )
        }

        let heartMetrics = try await healthKitManager.fetchHeartMetrics(from: dayStart, to: dayEnd)
        for metric in heartMetrics {
            let kind: HealthSampleKind = metric.kind == .restingHeartRate ? .restingHeartRate : .heartRate
            samples.append(
                HealthNormalizedSample(
                    id: metric.id,
                    kind: kind,
                    startDate: metric.date,
                    endDate: metric.date,
                    value: metric.value,
                    unitSymbol: metric.unitSymbol
                )
            )
        }

        let sleepRecords = try await healthKitManager.fetchSleepRecords(from: dayStart, to: dayEnd)
        for sleep in sleepRecords where sleep.asleepDuration > 0 {
            samples.append(
                HealthNormalizedSample(
                    id: sleep.id,
                    kind: .sleep,
                    startDate: sleep.startDate,
                    endDate: sleep.endDate,
                    value: sleep.asleepDuration / 60.0,
                    unitSymbol: HealthUnitSymbol.minutes
                )
            )
        }

        _ = calendar
        return samples
    }
}
