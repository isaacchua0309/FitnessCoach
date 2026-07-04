//
//  CrossDeviceSyncModels.swift
//  Fitness Coach
//
//  Forma — Cross-device sync mode, status, and summary types (Phase 5).
//
//  Models only. No coordinator, listener, or UI wiring in this file.
//

import Foundation

/// How cross-device sync work is being performed.
enum CrossDeviceSyncMode: String, Codable, Equatable, Sendable, CaseIterable {
    case foregroundRefresh
    case manualRefresh
    case realtimeListener
    case backgroundRefresh
    case afterRemoteChange
}

/// Lifecycle state for a cross-device sync run or listener session.
enum CrossDeviceSyncStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case idle
    case starting
    case uploadingLocalChanges
    case pullingRemoteChanges
    case listening
    case applyingRemoteChanges
    case completed
    case partial
    case offline
    case failed
    case cancelled
}

/// Why cross-device sync was started.
enum CrossDeviceSyncReason: String, Codable, Equatable, Sendable, CaseIterable {
    case appForeground
    case manualPullToRefresh
    case realtimeSnapshot
    case afterLocalMutation
    case afterRestore
    case accountSwitch
    case retry
}

/// Aggregated outcome of a cross-device sync pass (upload + pull + optional profile refresh).
struct CrossDeviceSyncSummary: Equatable, Sendable {
    let uid: String
    let mode: CrossDeviceSyncMode
    let reason: CrossDeviceSyncReason
    let status: CrossDeviceSyncStatus
    let startedAt: Date
    let endedAt: Date?
    let uploadedMutations: Int
    let pulledDailyLogs: Int
    let pulledFoodEntries: Int
    let pulledWaterEntries: Int
    let pulledWeightEntries: Int
    let pulledDailyReviews: Int
    let pulledProfile: Bool
    let inserted: Int
    let updated: Int
    let deleted: Int
    let skippedLocalNewer: Int
    let conflicts: Int
    let failed: Int
    let didRefreshUI: Bool
    let userFacingMessage: String?
}
