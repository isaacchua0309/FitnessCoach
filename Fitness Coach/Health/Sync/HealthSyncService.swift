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
        var daysCompleted = 0

        for offset in 0..<days {
            if Task.isCancelled {
                let cancelled = finalizeState(
                    trigger: trigger,
                    daysRequested: days,
                    daysCompleted: daysCompleted,
                    signalResults: signalResults,
                    error: .cancelled
                )
                state = cancelled
                return cancelled
            }

            guard let day = calendar.date(byAdding: .day, value: -offset, to: endingOn) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: day)
            let refresh = await repository.refreshHealthData(
                days: 1,
                endingOn: dayStart,
                calendar: calendar
            )
            if refresh.daysRefreshed > 0 {
                daysCompleted += 1
            }

            state = state.updating(
                phase: .syncing,
                trigger: trigger,
                progress: HealthSyncProgress(
                    daysRequested: days,
                    daysCompleted: daysCompleted,
                    currentDay: dayStart
                ),
                signalResults: signalResults,
                lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
                lastError: nil
            )
        }

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
        await withTaskGroup(of: HealthSyncSignalResult.self) { group in
            group.addTask {
                await self.syncWorkouts(days: days, availability: availability)
            }
            group.addTask {
                await self.syncSleep(days: days, availability: availability)
            }
            group.addTask {
                await self.syncRestingHeartRate(days: days, availability: availability)
            }
            group.addTask {
                await self.syncHeartRateVariability(days: days, availability: availability)
            }
            group.addTask {
                await self.syncBodyMass(days: days, availability: availability)
            }

            var results: [HealthSyncSignalResult] = []
            for await result in group {
                results.append(result)
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

    private func syncRestingHeartRate(
        days: Int,
        availability: HealthDataAvailability
    ) async -> HealthSyncSignalResult {
        let access = availability.permissionStatus.access(for: .restingHeartRate)
        guard access.isReadable else {
            let error: HealthSyncError = access == .denied
                ? .permissionDenied
                : .signalUnavailable(.restingHeartRate)
            HealthSyncLogger.signalFailure(signal: .restingHeartRate, context: "syncHeart", error: error)
            return .failure(signal: .restingHeartRate, error: error)
        }

        let metrics = await repository.getRecentHeartMetrics(days: days, calendar: calendar)
        let count = metrics.filter { $0.kind == .restingHeartRate }.count
        return .success(signal: .restingHeartRate, recordCount: count)
    }

    private func syncHeartRateVariability(
        days: Int,
        availability: HealthDataAvailability
    ) async -> HealthSyncSignalResult {
        let access = availability.permissionStatus.access(for: .heartRateVariabilitySDNN)
        guard access.isReadable else {
            let error: HealthSyncError = access == .denied
                ? .permissionDenied
                : .signalUnavailable(.heartRateVariabilitySDNN)
            HealthSyncLogger.signalFailure(
                signal: .heartRateVariabilitySDNN,
                context: "syncHeart",
                error: error
            )
            return .failure(signal: .heartRateVariabilitySDNN, error: error)
        }

        let metrics = await repository.getRecentHeartMetrics(days: days, calendar: calendar)
        let count = metrics.filter { $0.kind == .heartRateVariabilitySDNN }.count
        return .success(signal: .heartRateVariabilitySDNN, recordCount: count)
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
