//
//  HealthSyncService.swift
//  Fitness Coach
//
//  Forma — Coordinates HealthKit fetch, normalization, and cache refresh.
//

import Foundation

struct HealthSyncResult: Equatable, Sendable {
    let date: Date
    let sampleCount: Int
    let syncedAt: Date
}

protocol HealthSyncServing: Sendable {
    func syncDay(
        _ date: Date,
        calendar: Calendar
    ) async throws -> HealthSyncResult
    func syncRecentDays(
        count: Int,
        endingOn date: Date,
        calendar: Calendar
    ) async throws -> [HealthSyncResult]
}

struct HealthSyncService: HealthSyncServing {

    private let repository: any HealthDataRepositorying
    private let permissionService: any HealthPermissionServing

    init(
        repository: any HealthDataRepositorying = HealthDataRepository(),
        permissionService: any HealthPermissionServing = HealthPermissionService()
    ) {
        self.repository = repository
        self.permissionService = permissionService
    }

    func syncDay(
        _ date: Date,
        calendar: Calendar = .current
    ) async throws -> HealthSyncResult {
        let status = await permissionService.currentStatus()
        guard status.hasAnyAvailableReadAccess else {
            throw HealthDataRepositoryError.permissionDenied
        }

        let refresh = await repository.refreshHealthData(days: 1, endingOn: date, calendar: calendar)
        let samples = try await repository.normalizedSamples(for: date, calendar: calendar)
        return HealthSyncResult(
            date: calendar.startOfDay(for: date),
            sampleCount: samples.count,
            syncedAt: refresh.refreshedAt
        )
    }

    func syncRecentDays(
        count: Int,
        endingOn date: Date,
        calendar: Calendar = .current
    ) async throws -> [HealthSyncResult] {
        let dayCount = max(count, 0)
        var results: [HealthSyncResult] = []
        results.reserveCapacity(dayCount)

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else {
                continue
            }
            let result = try await syncDay(day, calendar: calendar)
            results.append(result)
        }

        return results
    }
}
