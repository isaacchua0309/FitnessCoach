//
//  HealthFallbackReason.swift
//  Fitness Coach
//
//  Forma — Deterministic reasons Health Intelligence surfaces fall back from full insight.
//

import Foundation

/// Why a Health Intelligence surface is not showing full insight confidence.
enum HealthFallbackReason: String, Equatable, Sendable, Codable, CaseIterable {
    case none
    case loading
    case syncInProgress
    case syncFailed
    case healthKitUnavailable
    case permissionsRequired
    case partialPermissions
    case staleLocalCache
    case insufficientBaselineHistory
    case noWorkoutHistory
    case missingSleepData
    case missingHeartMetrics
    case remoteSyncOptedOut
    case snapshotUnavailable
    case unknown
}
