//
//  HealthSyncService.swift
//  Fitness Coach
//
//  Forma — Coordinates HealthKit fetch, normalization, and local cache refresh.
//

import Foundation

protocol HealthSyncServing: Sendable {
    func getCurrentSyncState() async -> HealthSyncState
    func syncInitialHealthData() async -> HealthSyncState
    func syncToday() async -> HealthSyncState
    func syncLastNDays(_ days: Int) async -> HealthSyncState
    func refreshOnAppForeground() async -> HealthSyncState
}

extension HealthSyncServing {
    func syncLastNDays() async -> HealthSyncState {
        await syncLastNDays(HealthCachePolicy.retentionDays)
    }
}

actor HealthSyncService: HealthSyncServing {

    private let repository: any HealthDataRepositorying
    private let permissionService: any HealthPermissionServing
    private let cacheStore: any HealthCacheStore
    private let calendar: Calendar
    private let foregroundMinimumInterval: TimeInterval

    private var state: HealthSyncState = .idle
    private var isSyncing = false
    private var lastForegroundSyncAt: Date?

    init(
        repository: any HealthDataRepositorying = HealthDataRepository(),
        permissionService: any HealthPermissionServing = HealthPermissionService(),
        cacheStore: any HealthCacheStore = LocalHealthCacheStore(),
        calendar: Calendar = .current,
        foregroundMinimumInterval: TimeInterval = HealthCachePolicy.todayFreshnessInterval
    ) {
        self.repository = repository
        self.permissionService = permissionService
        self.cacheStore = cacheStore
        self.calendar = calendar
        self.foregroundMinimumInterval = foregroundMinimumInterval
    }

    // MARK: - Public API

    func getCurrentSyncState() async -> HealthSyncState {
        state
    }

    func syncInitialHealthData() async -> HealthSyncState {
        await runSync(trigger: .initial, days: HealthCachePolicy.retentionDays)
    }

    func syncToday() async -> HealthSyncState {
        await runSync(trigger: .today, days: 1)
    }

    func syncLastNDays(_ days: Int) async -> HealthSyncState {
        let resolvedDays = max(days, 1)
        await runSync(trigger: .manual, days: resolvedDays)
    }

    func refreshOnAppForeground() async -> HealthSyncState {
        if isSyncing {
            HealthSyncLogger.warn("foreground refresh skipped: sync in progress")
            return state
        }

        if let lastForegroundSyncAt,
           Date().timeIntervalSince(lastForegroundSyncAt) < foregroundMinimumInterval {
            HealthSyncLogger.event(
                "foreground refresh skipped: throttled",
                fields: [
                    "secondsSinceLast": String(Int(Date().timeIntervalSince(lastForegroundSyncAt)))
                ]
            )
            return state
        }

        lastForegroundSyncAt = Date()
        return await runSync(trigger: .foreground, days: 1)
    }

    // MARK: - Sync orchestration

    private func runSync(trigger: HealthSyncTrigger, days: Int) async -> HealthSyncState {
        if isSyncing {
            HealthSyncLogger.warn(
                "sync skipped: already in progress",
                fields: ["trigger": trigger.rawValue]
            )
            return state
        }

        isSyncing = true
        defer { isSyncing = false }

        let availability = await repository.getHealthDataAvailability()
        guard availability.isHealthDataAvailable else {
            let failed = state.updating(
                phase: .failed,
                trigger: trigger,
                progress: HealthSyncProgress(daysRequested: days, daysCompleted: 0, currentDay: nil),
                signalResults: [],
                lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
                lastError: .healthDataUnavailable
            )
            state = failed
            HealthSyncLogger.logState(failed, context: "unavailable")
            return failed
        }

        guard availability.permissionStatus.hasAnyAvailableReadAccess else {
            let failed = state.updating(
                phase: .failed,
                trigger: trigger,
                progress: HealthSyncProgress(daysRequested: days, daysCompleted: 0, currentDay: nil),
                signalResults: [],
                lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
                lastError: .permissionDenied
            )
            state = failed
            HealthSyncLogger.logState(failed, context: "permissionDenied")
            return failed
        }

        let endingOn = Date()
        state = state.updating(
            phase: .syncing,
            trigger: trigger,
            progress: HealthSyncProgress(daysRequested: days, daysCompleted: 0, currentDay: nil),
            signalResults: [],
            lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
            lastError: nil
        )
        HealthSyncLogger.event(
            "sync started",
            fields: [
                "trigger": trigger.rawValue,
                "days": String(days)
            ]
        )

        var signalResults: [HealthSyncSignalResult] = []
        let refresh = await repository.refreshHealthData(
            days: days,
            endingOn: endingOn,
            calendar: calendar
        )
        let daysCompleted = refresh.daysRefreshed

        state = state.updating(
            phase: .syncing,
            trigger: trigger,
            progress: HealthSyncProgress(
                daysRequested: days,
                daysCompleted: daysCompleted,
                currentDay: nil
            ),
            signalResults: signalResults,
            lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
            lastError: nil
        )

        let aggregateResults = await syncAggregateSignals(
            days: days,
            availability: availability
        )
        signalResults.append(contentsOf: aggregateResults)

        cacheStore.pruneOldEntries(
            keepingLastDays: HealthCachePolicy.retentionDays,
            calendar: calendar
        )

        let failedSignals = signalResults.filter { !$0.succeeded }
        let phase: HealthSyncPhase
        let lastError: HealthSyncError?

        if daysCompleted == 0 && !failedSignals.isEmpty {
            phase = .failed
            lastError = failedSignals.first?.error ?? .signalFailed(.stepCount, reason: "No days refreshed")
        } else if failedSignals.isEmpty {
            phase = .succeeded
            lastError = nil
        } else {
            phase = .partialSuccess
            lastError = failedSignals.first?.error
        }

        let finished = state.updating(
            phase: phase,
            trigger: trigger,
            progress: HealthSyncProgress(
                daysRequested: days,
                daysCompleted: daysCompleted,
                currentDay: nil
            ),
            signalResults: signalResults,
            lastSuccessfulSyncAt: phase == .failed ? state.lastSuccessfulSyncAt : Date(),
            lastError: lastError
        )
        state = finished
        HealthSyncLogger.logState(finished, context: "completed")
        return finished
    }

    private func syncAggregateSignals(
        days: Int,
        availability: HealthDataAvailability
    ) async -> [HealthSyncSignalResult] {
        await withTaskGroup(of: [HealthSyncSignalResult].self) { group in
            group.addTask {
                [await self.syncWorkouts(days: days, availability: availability)]
            }
            group.addTask {
                [await self.syncSleep(days: days, availability: availability)]
            }
            group.addTask {
                await self.syncHeartMetrics(days: days, availability: availability)
            }
            group.addTask {
                [await self.syncBodyMass(days: days, availability: availability)]
            }

            var results: [HealthSyncSignalResult] = []
            for await batch in group {
                results.append(contentsOf: batch)
            }
            return results.sorted { $0.signal.rawValue < $1.signal.rawValue }
        }
    }

    private func syncWorkouts(
        days: Int,
        availability: HealthDataAvailability
    ) async -> HealthSyncSignalResult {
        let access = availability.permissionStatus.access(for: .workout)
        guard access.isReadable else {
            let error: HealthSyncError = access == .denied
                ? .permissionDenied
                : .signalUnavailable(.workout)
            HealthSyncLogger.signalFailure(signal: .workout, context: "syncWorkouts", error: error)
            return .failure(signal: .workout, error: error)
        }

        let workouts = await repository.getRecentWorkouts(days: days, calendar: calendar)
        return .success(signal: .workout, recordCount: workouts.count)
    }

    private func syncSleep(
        days: Int,
        availability: HealthDataAvailability
    ) async -> HealthSyncSignalResult {
        let access = availability.permissionStatus.access(for: .sleepAnalysis)
        guard access.isReadable else {
            let error: HealthSyncError = access == .denied
                ? .permissionDenied
                : .signalUnavailable(.sleepAnalysis)
            HealthSyncLogger.signalFailure(signal: .sleepAnalysis, context: "syncSleep", error: error)
            return .failure(signal: .sleepAnalysis, error: error)
        }

        let records = await repository.getRecentSleep(days: days, calendar: calendar)
        return .success(signal: .sleepAnalysis, recordCount: records.count)
    }

    private func syncHeartMetrics(
        days: Int,
        availability: HealthDataAvailability
    ) async -> [HealthSyncSignalResult] {
        let restingAccess = availability.permissionStatus.access(for: .restingHeartRate)
        let hrvAccess = availability.permissionStatus.access(for: .heartRateVariabilitySDNN)

        guard restingAccess.isReadable || hrvAccess.isReadable else {
            var results: [HealthSyncSignalResult] = []
            if restingAccess == .denied || hrvAccess == .denied {
                let error = HealthSyncError.permissionDenied
                if restingAccess == .denied {
                    results.append(.failure(signal: .restingHeartRate, error: error))
                }
                if hrvAccess == .denied {
                    results.append(.failure(signal: .heartRateVariabilitySDNN, error: error))
                }
            }
            return results
        }

        let metrics = await repository.getRecentHeartMetrics(days: days, calendar: calendar)
        var results: [HealthSyncSignalResult] = []

        if restingAccess.isReadable {
            let count = metrics.filter { $0.kind == .restingHeartRate }.count
            results.append(.success(signal: .restingHeartRate, recordCount: count))
        } else {
            let error: HealthSyncError = restingAccess == .denied
                ? .permissionDenied
                : .signalUnavailable(.restingHeartRate)
            HealthSyncLogger.signalFailure(signal: .restingHeartRate, context: "syncHeart", error: error)
            results.append(.failure(signal: .restingHeartRate, error: error))
        }

        if hrvAccess.isReadable {
            let count = metrics.filter { $0.kind == .heartRateVariabilitySDNN }.count
            results.append(.success(signal: .heartRateVariabilitySDNN, recordCount: count))
        } else {
            let error: HealthSyncError = hrvAccess == .denied
                ? .permissionDenied
                : .signalUnavailable(.heartRateVariabilitySDNN)
            HealthSyncLogger.signalFailure(
                signal: .heartRateVariabilitySDNN,
                context: "syncHeart",
                error: error
            )
            results.append(.failure(signal: .heartRateVariabilitySDNN, error: error))
        }

        return results
    }

    private func syncBodyMass(
        days: Int,
        availability: HealthDataAvailability
    ) async -> HealthSyncSignalResult {
        let access = availability.permissionStatus.access(for: .bodyMass)
        guard access.isReadable else {
            let error: HealthSyncError = access == .denied
                ? .permissionDenied
                : .signalUnavailable(.bodyMass)
            HealthSyncLogger.signalFailure(signal: .bodyMass, context: "syncBodyMass", error: error)
            return .failure(signal: .bodyMass, error: error)
        }

        let records = await repository.getBodyMassHistory(days: days, calendar: calendar)
        return .success(signal: .bodyMass, recordCount: records.count)
    }

    private func finalizeState(
        trigger: HealthSyncTrigger,
        daysRequested: Int,
        daysCompleted: Int,
        signalResults: [HealthSyncSignalResult],
        error: HealthSyncError
    ) -> HealthSyncState {
        state.updating(
            phase: .failed,
            trigger: trigger,
            progress: HealthSyncProgress(
                daysRequested: daysRequested,
                daysCompleted: daysCompleted,
                currentDay: nil
            ),
            signalResults: signalResults,
            lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
            lastError: error
        )
    }
}

// MARK: - Legacy result type

struct HealthSyncResult: Equatable, Sendable {
    let date: Date
    let sampleCount: Int
    let syncedAt: Date
}

extension HealthSyncService {
    func syncDay(
        _ date: Date,
        calendar: Calendar? = nil
    ) async throws -> HealthSyncResult {
        let resolvedCalendar = calendar ?? self.calendar
        let status = await permissionService.currentStatus()
        guard status.hasAnyAvailableReadAccess else {
            throw HealthSyncError.permissionDenied
        }

        let refresh = await repository.refreshHealthData(
            days: 1,
            endingOn: date,
            calendar: resolvedCalendar
        )
        let samples = try await repository.normalizedSamples(for: date, calendar: resolvedCalendar)
        return HealthSyncResult(
            date: resolvedCalendar.startOfDay(for: date),
            sampleCount: samples.count,
            syncedAt: refresh.refreshedAt
        )
    }
}
