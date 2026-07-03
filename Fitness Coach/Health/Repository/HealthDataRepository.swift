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
            let rawSamples = try await healthKitManager.fetchSamples(from: dayStart, to: dayEnd)
            let normalized = normalizer.normalize(samples: rawSamples)
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
}
