//
//  HealthSyncState.swift
//  Fitness Coach
//
//  Forma — Observable sync lifecycle and per-signal results.
//

import Foundation

enum HealthSyncPhase: String, Equatable, Sendable {
    case idle
    case syncing
    case succeeded
    case partialSuccess
    case failed
}

enum HealthSyncTrigger: String, Equatable, Sendable {
    case initial
    case today
    case lastNDays
    case foreground
    case manual
    case daily
}

struct HealthSyncProgress: Equatable, Sendable {
    let daysRequested: Int
    let daysCompleted: Int
    let currentDay: Date?

    var fractionCompleted: Double {
        guard daysRequested > 0 else { return 0 }
        return min(1, Double(daysCompleted) / Double(daysRequested))
    }

    static let zero = HealthSyncProgress(daysRequested: 0, daysCompleted: 0, currentDay: nil)
}

struct HealthSyncSignalResult: Equatable, Sendable {
    let signal: HealthSignalKind
    let succeeded: Bool
    let recordCount: Int
    let error: HealthSyncError?

    static func success(signal: HealthSignalKind, recordCount: Int) -> HealthSyncSignalResult {
        HealthSyncSignalResult(signal: signal, succeeded: true, recordCount: recordCount, error: nil)
    }

    static func failure(signal: HealthSignalKind, error: HealthSyncError) -> HealthSyncSignalResult {
        HealthSyncSignalResult(signal: signal, succeeded: false, recordCount: 0, error: error)
    }
}

struct HealthSyncState: Equatable, Sendable {
    let phase: HealthSyncPhase
    let trigger: HealthSyncTrigger?
    let progress: HealthSyncProgress
    let signalResults: [HealthSyncSignalResult]
    let lastSuccessfulSyncAt: Date?
    let lastError: HealthSyncError?
    let updatedAt: Date

    var isSyncing: Bool { phase == .syncing }

    static let idle = HealthSyncState(
        phase: .idle,
        trigger: nil,
        progress: .zero,
        signalResults: [],
        lastSuccessfulSyncAt: nil,
        lastError: nil,
        updatedAt: Date()
    )

    func updating(
        phase: HealthSyncPhase,
        trigger: HealthSyncTrigger?,
        progress: HealthSyncProgress,
        signalResults: [HealthSyncSignalResult],
        lastSuccessfulSyncAt: Date?,
        lastError: HealthSyncError?
    ) -> HealthSyncState {
        HealthSyncState(
            phase: phase,
            trigger: trigger,
            progress: progress,
            signalResults: signalResults,
            lastSuccessfulSyncAt: lastSuccessfulSyncAt,
            lastError: lastError,
            updatedAt: Date()
        )
    }
}
