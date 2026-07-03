//
//  HealthSummaryRemoteSyncState.swift
//  Fitness Coach
//
//  Forma — Runtime and persisted state for remote Health Summary Sync.
//

import Foundation

enum HealthSummaryRemoteSyncPhase: String, Equatable, Sendable {
    case disabled
    case idle
    case syncing
    case succeeded
    case partialSuccess
    case failed
}

enum HealthSummaryRemoteSyncTrigger: String, Equatable, Sendable {
    case initial
    case manual
    case today
    case foreground
    case afterLocalRefresh
    case weeklyReview
}

enum HealthSummaryRemoteSyncPayloadKind: String, Equatable, Sendable, CaseIterable {
    case daily
    case workouts
    case recovery
    case weeklyReview
    case metadata
}

struct HealthSummaryRemoteSyncState: Equatable, Sendable {
    let phase: HealthSummaryRemoteSyncPhase
    let trigger: HealthSummaryRemoteSyncTrigger?
    let lastSuccessfulRemoteSyncAt: Date?
    let lastAttemptedRemoteSyncAt: Date?
    let lastError: HealthSummarySyncError?
    let failedPayloadKinds: [HealthSummaryRemoteSyncPayloadKind]
    let backoffUntil: Date?
    let updatedAt: Date

    var isSyncing: Bool { phase == .syncing }

    static let disabled = HealthSummaryRemoteSyncState(
        phase: .disabled,
        trigger: nil,
        lastSuccessfulRemoteSyncAt: nil,
        lastAttemptedRemoteSyncAt: nil,
        lastError: nil,
        failedPayloadKinds: [],
        backoffUntil: nil,
        updatedAt: Date()
    )

    static let idle = HealthSummaryRemoteSyncState(
        phase: .idle,
        trigger: nil,
        lastSuccessfulRemoteSyncAt: nil,
        lastAttemptedRemoteSyncAt: nil,
        lastError: nil,
        failedPayloadKinds: [],
        backoffUntil: nil,
        updatedAt: Date()
    )

    func updating(
        phase: HealthSummaryRemoteSyncPhase,
        trigger: HealthSummaryRemoteSyncTrigger?,
        lastSuccessfulRemoteSyncAt: Date?,
        lastAttemptedRemoteSyncAt: Date?,
        lastError: HealthSummarySyncError?,
        failedPayloadKinds: [HealthSummaryRemoteSyncPayloadKind],
        backoffUntil: Date?
    ) -> HealthSummaryRemoteSyncState {
        HealthSummaryRemoteSyncState(
            phase: phase,
            trigger: trigger,
            lastSuccessfulRemoteSyncAt: lastSuccessfulRemoteSyncAt,
            lastAttemptedRemoteSyncAt: lastAttemptedRemoteSyncAt,
            lastError: lastError,
            failedPayloadKinds: failedPayloadKinds,
            backoffUntil: backoffUntil,
            updatedAt: Date()
        )
    }
}

struct HealthSummaryRemoteSyncPersistedState: Codable, Equatable, Sendable {
    var lastSuccessfulRemoteSyncAt: Date?
    var lastAttemptedRemoteSyncAt: Date?
    var consecutiveFailures: Int
    var backoffUntil: Date?

    static let empty = HealthSummaryRemoteSyncPersistedState(
        lastSuccessfulRemoteSyncAt: nil,
        lastAttemptedRemoteSyncAt: nil,
        consecutiveFailures: 0,
        backoffUntil: nil
    )
}

enum HealthSummarySyncPolicy {
    static let defaultSyncWindowDays = 30
    static let initialSyncWindowDays = 90
    static let foregroundMinimumInterval: TimeInterval = 15 * 60
    static let minimumRetryInterval: TimeInterval = 60
    static let maxBackoffInterval: TimeInterval = 30 * 60
    static let maxBackoffExponent = 5

    static func resolvedSyncWindowDays(
        requestedDays: Int,
        trigger: HealthSummaryRemoteSyncTrigger,
        hasPriorSuccessfulRemoteSync: Bool
    ) -> Int {
        let boundedRetention = HealthCachePolicy.retentionDays

        if !hasPriorSuccessfulRemoteSync {
            return min(
                max(initialSyncWindowDays, 1),
                boundedRetention
            )
        }

        let normalizedRequest = max(requestedDays, 1)

        switch trigger {
        case .manual, .initial:
            return min(normalizedRequest, boundedRetention)
        case .today:
            return 1
        default:
            return min(normalizedRequest, defaultSyncWindowDays, boundedRetention)
        }
    }

    static func backoffInterval(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return 0 }
        let exponent = min(consecutiveFailures, maxBackoffExponent)
        let scaled = minimumRetryInterval * pow(2.0, Double(exponent - 1))
        return min(scaled, maxBackoffInterval)
    }
}
