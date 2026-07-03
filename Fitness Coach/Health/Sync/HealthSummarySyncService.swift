//
//  HealthSummarySyncService.swift
//  Fitness Coach
//
//  Forma — Coordinates uploading normalized local health summaries to the backend.
//
//  Reads cached normalized data only, composes contract payloads, and uploads through
//  `HealthSummaryRemoteSyncing`. Never uploads raw HealthKit samples or blocks UI callers.
//

import Foundation

protocol HealthSummarySyncServing: Sendable {
    func syncRecentHealthSummaries(days: Int) async
    func syncTodayHealthSummary() async
    func syncWeeklyReviewIfAvailable() async
    func syncAfterLocalHealthRefresh(days: Int) async
    func syncOnAppForeground() async
    func getRemoteSyncState() async -> HealthSummaryRemoteSyncState
    func deleteRemoteHealthSummaries() async throws
    func cancelActiveSync() async
}

extension HealthSummarySyncServing {
    func cancelActiveSync() async {}
}

extension HealthSummarySyncServing {
    func syncRecentHealthSummaries() async {
        await syncRecentHealthSummaries(days: HealthSummarySyncPolicy.defaultSyncWindowDays)
    }
}

actor HealthSummarySyncService: HealthSummarySyncServing {

    private let remoteSyncClient: any HealthSummaryRemoteSyncing
    private let cacheStore: any HealthCacheStore
    private let repository: any HealthDataRepositorying
    private let userProvider: any HealthCacheUserProviding
    private let stateStore: any HealthSummaryRemoteSyncStateStoring
    private let localHealthSyncService: (any HealthSyncServing)?
    private let calendar: Calendar
    private let foregroundMinimumInterval: TimeInterval
    private let remoteSyncEnabled: @Sendable () -> Bool

    private var state: HealthSummaryRemoteSyncState
    private var isSyncing = false
    private var lastForegroundSyncAt: Date?
    private var activeSyncGeneration = 0

    init(
        remoteSyncClient: any HealthSummaryRemoteSyncing,
        cacheStore: any HealthCacheStore,
        repository: any HealthDataRepositorying,
        userProvider: any HealthCacheUserProviding,
        stateStore: any HealthSummaryRemoteSyncStateStoring = UserDefaultsHealthSummaryRemoteSyncStateStore(),
        localHealthSyncService: (any HealthSyncServing)? = nil,
        calendar: Calendar = .current,
        foregroundMinimumInterval: TimeInterval = HealthSummarySyncPolicy.foregroundMinimumInterval,
        remoteSyncEnabled: @escaping @Sendable () -> Bool = {
            HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        }
    ) {
        self.remoteSyncClient = remoteSyncClient
        self.cacheStore = cacheStore
        self.repository = repository
        self.userProvider = userProvider
        self.stateStore = stateStore
        self.localHealthSyncService = localHealthSyncService
        self.calendar = calendar
        self.foregroundMinimumInterval = foregroundMinimumInterval
        self.remoteSyncEnabled = remoteSyncEnabled
        self.state = .idle
    }

    // MARK: - Public API

    func getRemoteSyncState() async -> HealthSummaryRemoteSyncState {
        guard remoteSyncEnabled() else {
            return disabledState()
        }
        return state
    }

    func deleteRemoteHealthSummaries() async throws {
        await cancelActiveSync()
        guard HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled else { return }
        guard !isSyncing else {
            throw HealthSummarySyncError.deleteFailed(reason: "sync_in_progress")
        }

        guard let userID = authenticatedUserID() else {
            throw HealthSummarySyncError.notAuthenticated
        }

        try await remoteSyncClient.deleteRemoteHealthSummaries()
        stateStore.clear(for: userID)
        state = .idle

        HealthSummaryRemoteSyncLogger.serviceEvent(
            "remote health summaries deleted",
            fields: ["uid": userID]
        )
    }

    func syncRecentHealthSummaries(days: Int) async {
        await runSync(
            trigger: .manual,
            requestedDays: days,
            bypassBackoff: true
        )
    }

    func syncTodayHealthSummary() async {
        await runSync(
            trigger: .today,
            requestedDays: 1,
            bypassBackoff: false
        )
    }

    func syncWeeklyReviewIfAvailable() async {
        guard remoteSyncEnabled() else {
            state = disabledState()
            return
        }

        guard !isSyncing else {
        HealthSummaryRemoteSyncLogger.serviceWarn("weekly review sync skipped: already in progress")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        guard let userID = authenticatedUserID() else {
            state = unauthenticatedState()
            return
        }

        guard shouldAttemptSync(userID: userID, bypassBackoff: false) else {
            return
        }

        let persisted = stateStore.load(for: userID)
        markAttemptStarted(userID: userID, trigger: .weeklyReview, persisted: persisted)

        guard let review = latestCachedWeeklyReview() else {
            finishAttempt(
                userID: userID,
                trigger: .weeklyReview,
                failedKinds: [],
                lastError: nil,
                didUploadAnyPayload: false
            )
            return
        }

        let context = makeMappingContext(userID: userID)
        var failedKinds: [HealthSummaryRemoteSyncPayloadKind] = []
        var lastError: HealthSummarySyncError?
        var didUploadAnyPayload = false

        if let payload = WeeklyHealthReviewSyncPayload.make(from: review, context: context) {
            do {
                try await remoteSyncClient.uploadWeeklyReviews([payload])
                didUploadAnyPayload = true
            } catch let error as HealthSummarySyncError {
                failedKinds.append(.weeklyReview)
                lastError = error
                HealthSummaryRemoteSyncLogger.payloadKindFailed(.weeklyReview, error: error)
            } catch {
                let mapped = HealthSummarySyncError.uploadFailed(collection: "weeklyReview", reason: "unexpected")
                failedKinds.append(.weeklyReview)
                lastError = mapped
                HealthSummaryRemoteSyncLogger.payloadKindFailed(.weeklyReview, error: mapped)
            }
        }

        if didUploadAnyPayload {
            await uploadMetadata(
                userID: userID,
                context: context,
                syncWindowDays: HealthSummarySyncPolicy.defaultSyncWindowDays,
                failedKinds: &failedKinds,
                lastError: &lastError
            )
        }

        finishAttempt(
            userID: userID,
            trigger: .weeklyReview,
            failedKinds: failedKinds,
            lastError: lastError,
            didUploadAnyPayload: didUploadAnyPayload
        )
    }

    func syncAfterLocalHealthRefresh(days: Int) async {
        await runSync(
            trigger: .afterLocalRefresh,
            requestedDays: days,
            bypassBackoff: false
        )
    }

    func syncOnAppForeground() async {
        if isSyncing {
            HealthSummaryRemoteSyncLogger.serviceWarn("foreground remote sync skipped: already in progress")
            return
        }

        if let lastForegroundSyncAt,
           Date().timeIntervalSince(lastForegroundSyncAt) < foregroundMinimumInterval {
            HealthSummaryRemoteSyncLogger.serviceEvent(
                "foreground remote sync skipped: throttled",
                fields: [
                    "secondsSinceLast": String(Int(Date().timeIntervalSince(lastForegroundSyncAt)))
                ]
            )
            return
        }

        lastForegroundSyncAt = Date()
        await runSync(
            trigger: .foreground,
            requestedDays: 1,
            bypassBackoff: false
        )
    }

    func cancelActiveSync() async {
        activeSyncGeneration += 1
        isSyncing = false
    }

    // MARK: - Orchestration

    private func runSync(
        trigger: HealthSummaryRemoteSyncTrigger,
        requestedDays: Int,
        bypassBackoff: Bool
    ) async {
        guard remoteSyncEnabled() else {
            state = disabledState()
            return
        }

        guard !isSyncing else {
            HealthSummaryRemoteSyncLogger.serviceWarn(
                "remote summary sync skipped: already in progress",
                fields: ["trigger": trigger.rawValue]
            )
            return
        }

        isSyncing = true
        let generation = activeSyncGeneration
        defer {
            if generation == activeSyncGeneration {
                isSyncing = false
            }
        }

        guard !Task.isCancelled else { return }

        guard let userID = authenticatedUserID() else {
            state = unauthenticatedState()
            return
        }

        guard shouldAttemptSync(userID: userID, bypassBackoff: bypassBackoff) else {
            return
        }

        var persisted = stateStore.load(for: userID)
        let resolvedTrigger: HealthSummaryRemoteSyncTrigger = persisted.lastSuccessfulRemoteSyncAt == nil
            ? .initial
            : trigger
        let syncWindowDays = HealthSummarySyncPolicy.resolvedSyncWindowDays(
            requestedDays: requestedDays,
            trigger: resolvedTrigger,
            hasPriorSuccessfulRemoteSync: persisted.lastSuccessfulRemoteSyncAt != nil
        )

        markAttemptStarted(userID: userID, trigger: resolvedTrigger, persisted: &persisted)

        HealthSummarySyncDebugLogger.remoteSyncStarted(
            trigger: resolvedTrigger.rawValue,
            syncWindowDays: syncWindowDays
        )
        let remoteSyncStartedAt = Date()

        let availability = await repository.getHealthDataAvailability()
        let context = makeMappingContext(userID: userID)
        let endingOn = Date()
        let dayRange = Self.dayRange(
            days: syncWindowDays,
            endingOn: endingOn,
            calendar: calendar
        )

        let composed = HealthSummarySyncPayloadComposer.compose(
            days: dayRange,
            cacheStore: cacheStore,
            availability: availability,
            context: context,
            calendar: calendar
        )

        HealthSummarySyncDebugLogger.remoteSyncAttempted(
            trigger: resolvedTrigger.rawValue,
            syncWindowDays: syncWindowDays,
            dailyCount: composed.dailySummaries.count,
            workoutCount: composed.workoutSummaries.count,
            recoveryCount: composed.recoverySummaries.count
        )

        var failedKinds: [HealthSummaryRemoteSyncPayloadKind] = []
        var lastError: HealthSummarySyncError?
        var didUploadAnyPayload = false

        if remoteSyncStillActive(generation: generation) {
            didUploadAnyPayload = await uploadIfNotEmpty(
                composed.dailySummaries,
                kind: .daily,
                failedKinds: &failedKinds,
                lastError: &lastError
            ) {
                try await remoteSyncClient.uploadDailySummaries(composed.dailySummaries)
            } || didUploadAnyPayload
        }

        if remoteSyncStillActive(generation: generation) {
            didUploadAnyPayload = await uploadIfNotEmpty(
                composed.workoutSummaries,
                kind: .workouts,
                failedKinds: &failedKinds,
                lastError: &lastError
            ) {
                try await remoteSyncClient.uploadWorkoutSummaries(composed.workoutSummaries)
            } || didUploadAnyPayload
        }

        if remoteSyncStillActive(generation: generation) {
            didUploadAnyPayload = await uploadIfNotEmpty(
                composed.recoverySummaries,
                kind: .recovery,
                failedKinds: &failedKinds,
                lastError: &lastError
            ) {
                try await remoteSyncClient.uploadRecoverySummaries(composed.recoverySummaries)
            } || didUploadAnyPayload
        }

        if didUploadAnyPayload, remoteSyncStillActive(generation: generation) {
            await uploadMetadata(
                userID: userID,
                context: context,
                syncWindowDays: syncWindowDays,
                failedKinds: &failedKinds,
                lastError: &lastError
            )
        }

        guard remoteSyncStillActive(generation: generation) else {
            return
        }

        finishAttempt(
            userID: userID,
            trigger: resolvedTrigger,
            failedKinds: failedKinds,
            lastError: lastError,
            didUploadAnyPayload: didUploadAnyPayload
        )

        let metadataAttempted = didUploadAnyPayload
        let metadataUploaded = metadataAttempted && !failedKinds.contains(.metadata)
        let durationMs = Int(Date().timeIntervalSince(remoteSyncStartedAt) * 1_000)

        switch state.phase {
        case .succeeded:
            HealthSummarySyncDebugLogger.remoteSyncSucceeded(
                trigger: resolvedTrigger.rawValue,
                dailyCount: composed.dailySummaries.count,
                workoutCount: composed.workoutSummaries.count,
                recoveryCount: composed.recoverySummaries.count,
                metadataUploaded: metadataUploaded,
                durationMs: durationMs
            )
            HealthIntelligencePipelineAnalytics.logRemoteSyncFinished(
                phase: .succeeded,
                trigger: resolvedTrigger.rawValue,
                dailyCount: composed.dailySummaries.count,
                workoutCount: composed.workoutSummaries.count,
                recoveryCount: composed.recoverySummaries.count,
                errorDescription: nil
            )
        case .partialSuccess, .failed:
            HealthSummarySyncDebugLogger.remoteSyncFailed(
                trigger: resolvedTrigger.rawValue,
                phase: state.phase.rawValue,
                failedKinds: failedKinds,
                error: lastError,
                durationMs: durationMs
            )
            HealthIntelligencePipelineAnalytics.logRemoteSyncFinished(
                phase: state.phase,
                trigger: resolvedTrigger.rawValue,
                dailyCount: composed.dailySummaries.count,
                workoutCount: composed.workoutSummaries.count,
                recoveryCount: composed.recoverySummaries.count,
                errorDescription: lastError?.localizedDescription
            )
        default:
            break
        }
    }

    // MARK: - Upload helpers

    private func uploadIfNotEmpty<T>(
        _ payloads: [T],
        kind: HealthSummaryRemoteSyncPayloadKind,
        failedKinds: inout [HealthSummaryRemoteSyncPayloadKind],
        lastError: inout HealthSummarySyncError?,
        upload: () async throws -> Void
    ) async -> Bool {
        guard !payloads.isEmpty else { return false }

        do {
            try await upload()
            return true
        } catch let error as HealthSummarySyncError {
            failedKinds.append(kind)
            lastError = error
            HealthSummaryRemoteSyncLogger.payloadKindFailed(kind, error: error)
            return false
        } catch {
            let mapped = HealthSummarySyncError.uploadFailed(
                collection: kind.rawValue,
                reason: "unexpected"
            )
            failedKinds.append(kind)
            lastError = mapped
            HealthSummaryRemoteSyncLogger.payloadKindFailed(kind, error: mapped)
            return false
        }
    }

    private func uploadMetadata(
        userID: String,
        context: HealthSummarySyncMappingContext,
        syncWindowDays: Int,
        failedKinds: inout [HealthSummaryRemoteSyncPayloadKind],
        lastError: inout HealthSummarySyncError?
    ) async {
        let availability = await repository.getHealthDataAvailability()
        let localSyncState = await localHealthSyncService?.getCurrentSyncState() ?? .idle
        let metadata = HealthSyncMetadataPayload.make(
            from: localSyncState,
            availability: availability,
            context: context,
            syncWindowDays: syncWindowDays,
            appVersion: Self.appVersionString()
        )

        do {
            try await remoteSyncClient.uploadSyncMetadata(metadata)
        } catch let error as HealthSummarySyncError {
            failedKinds.append(.metadata)
            lastError = error
            HealthSummaryRemoteSyncLogger.payloadKindFailed(.metadata, error: error)
        } catch {
            let mapped = HealthSummarySyncError.uploadFailed(collection: "metadata", reason: "unexpected")
            failedKinds.append(.metadata)
            lastError = mapped
            HealthSummaryRemoteSyncLogger.payloadKindFailed(.metadata, error: mapped)
        }
    }

    // MARK: - State helpers

    private func authenticatedUserID() -> String? {
        let raw = userProvider.currentUserID()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty, raw != HealthCachePolicy.anonymousUserID else {
            HealthSummaryRemoteSyncLogger.serviceWarn("remote summary sync skipped: unauthenticated")
            return nil
        }
        return raw
    }

    private func remoteSyncStillActive(generation: Int) -> Bool {
        generation == activeSyncGeneration
            && remoteSyncEnabled()
            && !Task.isCancelled
    }

    private func shouldAttemptSync(userID: String, bypassBackoff: Bool) -> Bool {
        let persisted = stateStore.load(for: userID)
        if bypassBackoff {
            return true
        }
        if let backoffUntil = persisted.backoffUntil, Date() < backoffUntil {
            state = state.updating(
                phase: .idle,
                trigger: state.trigger,
                lastSuccessfulRemoteSyncAt: persisted.lastSuccessfulRemoteSyncAt,
                lastAttemptedRemoteSyncAt: persisted.lastAttemptedRemoteSyncAt,
                lastError: state.lastError,
                failedPayloadKinds: state.failedPayloadKinds,
                backoffUntil: backoffUntil
            )
            HealthSummaryRemoteSyncLogger.serviceEvent(
                "remote summary sync skipped: backoff active",
                fields: ["backoffUntil": ISO8601DateFormatter().string(from: backoffUntil)]
            )
            return false
        }
        return true
    }

    private func markAttemptStarted(
        userID: String,
        trigger: HealthSummaryRemoteSyncTrigger,
        persisted: inout HealthSummaryRemoteSyncPersistedState
    ) {
        let now = Date()
        persisted.lastAttemptedRemoteSyncAt = now
        stateStore.save(persisted, for: userID)

        state = state.updating(
            phase: .syncing,
            trigger: trigger,
            lastSuccessfulRemoteSyncAt: persisted.lastSuccessfulRemoteSyncAt,
            lastAttemptedRemoteSyncAt: now,
            lastError: nil,
            failedPayloadKinds: [],
            backoffUntil: persisted.backoffUntil
        )

        HealthSummaryRemoteSyncLogger.serviceEvent(
            "remote summary sync started",
            fields: ["trigger": trigger.rawValue]
        )
    }

    private func markAttemptStarted(
        userID: String,
        trigger: HealthSummaryRemoteSyncTrigger,
        persisted: HealthSummaryRemoteSyncPersistedState
    ) {
        var mutable = persisted
        markAttemptStarted(userID: userID, trigger: trigger, persisted: &mutable)
    }

    private func finishAttempt(
        userID: String,
        trigger: HealthSummaryRemoteSyncTrigger,
        failedKinds: [HealthSummaryRemoteSyncPayloadKind],
        lastError: HealthSummarySyncError?,
        didUploadAnyPayload: Bool
    ) {
        var persisted = stateStore.load(for: userID)
        let now = Date()

        let phase: HealthSummaryRemoteSyncPhase
        if failedKinds.isEmpty, didUploadAnyPayload {
            phase = .succeeded
            persisted.lastSuccessfulRemoteSyncAt = now
            persisted.consecutiveFailures = 0
            persisted.backoffUntil = nil
        } else if didUploadAnyPayload {
            phase = .partialSuccess
            persisted.consecutiveFailures += 1
            persisted.backoffUntil = now.addingTimeInterval(
                HealthSummarySyncPolicy.backoffInterval(consecutiveFailures: persisted.consecutiveFailures)
            )
        } else if failedKinds.isEmpty, !didUploadAnyPayload {
            phase = .idle
        } else {
            phase = .failed
            persisted.consecutiveFailures += 1
            persisted.backoffUntil = now.addingTimeInterval(
                HealthSummarySyncPolicy.backoffInterval(consecutiveFailures: persisted.consecutiveFailures)
            )
        }

        stateStore.save(persisted, for: userID)

        state = state.updating(
            phase: phase,
            trigger: trigger,
            lastSuccessfulRemoteSyncAt: persisted.lastSuccessfulRemoteSyncAt,
            lastAttemptedRemoteSyncAt: persisted.lastAttemptedRemoteSyncAt,
            lastError: lastError,
            failedPayloadKinds: failedKinds,
            backoffUntil: persisted.backoffUntil
        )

        HealthSummaryRemoteSyncLogger.serviceEvent(
            "remote summary sync finished",
            fields: [
                "trigger": trigger.rawValue,
                "phase": phase.rawValue,
                "failedKinds": failedKinds.map(\.rawValue).joined(separator: ","),
                "uploadedAny": didUploadAnyPayload ? "true" : "false"
            ]
        )
    }

    private func disabledState() -> HealthSummaryRemoteSyncState {
        .disabled
    }

    private func unauthenticatedState() -> HealthSummaryRemoteSyncState {
        state.updating(
            phase: .idle,
            trigger: nil,
            lastSuccessfulRemoteSyncAt: state.lastSuccessfulRemoteSyncAt,
            lastAttemptedRemoteSyncAt: state.lastAttemptedRemoteSyncAt,
            lastError: .notAuthenticated,
            failedPayloadKinds: [],
            backoffUntil: state.backoffUntil
        )
    }

    private func makeMappingContext(userID: String) -> HealthSummarySyncMappingContext {
        HealthSummarySyncMappingContext(
            userId: userID,
            calendar: calendar,
            generatedAt: Date(),
            source: .appleHealth
        )
    }

    private func latestCachedWeeklyReview() -> WeeklyHealthReview? {
        guard let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
            referenceDate: Date(),
            calendar: calendar
        ) else {
            return nil
        }
        return cacheStore.weeklyReview(for: weekStart, calendar: calendar)
    }

    private static func dayRange(days: Int, endingOn: Date, calendar: Calendar) -> [Date] {
        let end = calendar.startOfDay(for: endingOn)
        guard days > 0,
              let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else {
            return []
        }

        var result: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = end
        while cursor <= endDay {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return result
    }

    private static func appVersionString() -> String? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), nil):
            return version
        default:
            return nil
        }
    }
}

// MARK: - Payload composition

struct HealthSummarySyncComposedPayloads: Equatable, Sendable {
    let dailySummaries: [HealthDailySummarySyncPayload]
    let workoutSummaries: [HealthWorkoutSummarySyncPayload]
    let recoverySummaries: [RecoverySummarySyncPayload]
}

enum HealthSummarySyncPayloadComposer {

    static func compose(
        days: [Date],
        cacheStore: any HealthCacheStore,
        availability: HealthDataAvailability,
        context: HealthSummarySyncMappingContext,
        calendar: Calendar
    ) -> HealthSummarySyncComposedPayloads {
        guard !days.isEmpty else {
            return HealthSummarySyncComposedPayloads(
                dailySummaries: [],
                workoutSummaries: [],
                recoverySummaries: []
            )
        }

        let rangeStart = days.min() ?? days[0]
        let rangeEnd = days.max() ?? days[0]
        let workouts = cacheStore.workouts(from: rangeStart, to: rangeEnd, calendar: calendar)
        let missingDailySignals = missingDailySignals(from: availability)
        let dailyConfidence = confidence(for: missingDailySignals)

        var dailySummaries: [HealthDailySummarySyncPayload] = []
        dailySummaries.reserveCapacity(days.count)

        for day in days {
            guard let metrics = cacheStore.dailyMetrics(for: day, calendar: calendar) else {
                continue
            }

            dailySummaries.append(
                HealthDailySummarySyncPayload.make(
                    from: metrics,
                    workouts: workouts,
                    context: context,
                    confidence: dailyConfidence,
                    missingSignals: missingDailySignals
                )
            )
        }

        var workoutSummaries: [HealthWorkoutSummarySyncPayload] = []
        workoutSummaries.reserveCapacity(workouts.count)

        for workout in workouts {
            let dayStart = calendar.startOfDay(for: workout.startDate)
            let snapshot = cacheStore.intelligenceSnapshot(for: dayStart, calendar: calendar)
            workoutSummaries.append(
                HealthWorkoutSummarySyncPayload.make(
                    from: workout,
                    summary: snapshot?.workout,
                    context: context,
                    missingSignals: missingDailySignals
                )
            )
        }

        var recoverySummaries: [RecoverySummarySyncPayload] = []
        recoverySummaries.reserveCapacity(days.count)

        for day in days {
            let recovery = cacheStore.recoverySummary(for: day, calendar: calendar)
                ?? cacheStore.intelligenceSnapshot(for: day, calendar: calendar)?.recovery
            guard let recovery else { continue }

            recoverySummaries.append(
                RecoverySummarySyncPayload.make(
                    from: recovery,
                    date: day,
                    context: context
                )
            )
        }

        return HealthSummarySyncComposedPayloads(
            dailySummaries: dailySummaries,
            workoutSummaries: workoutSummaries,
            recoverySummaries: recoverySummaries
        )
    }

    static func missingDailySignals(
        from availability: HealthDataAvailability
    ) -> [HealthDailySummaryMissingSignal] {
        let status = availability.permissionStatus
        var missing: [HealthDailySummaryMissingSignal] = []

        if !status.access(for: .stepCount).isReadable {
            missing.append(.steps)
        }
        if !status.access(for: .activeEnergyBurned).isReadable {
            missing.append(.activeEnergy)
        }
        if !status.access(for: .appleExerciseTime).isReadable {
            missing.append(.exerciseMinutes)
        }
        if !status.access(for: .workout).isReadable {
            missing.append(.workout)
            missing.append(.workoutCalories)
        }

        return missing
    }

    private static func confidence(
        for missingSignals: [HealthDailySummaryMissingSignal]
    ) -> HealthSyncConfidence {
        if missingSignals.isEmpty {
            return .moderate
        }
        if missingSignals.count >= 3 {
            return .low
        }
        return .moderate
    }
}
