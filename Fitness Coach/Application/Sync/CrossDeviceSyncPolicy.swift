//
//  CrossDeviceSyncPolicy.swift
//  Fitness Coach
//
//  Forma — Centralized cross-device sync policy (Phase 5).
//
//  Lookback windows, throttles, timeouts, and scope exclusions.
//  No coordinator, listener, or UI wiring in this file.
//

import Foundation

/// Central policy for cross-device refresh and near-realtime consistency.
enum CrossDeviceSyncPolicy {

    // MARK: - Lookback windows (days)

    /// Narrow window for app-foreground refresh — keep foreground sync quick.
    static let foregroundPullLookbackDays = 14

    /// Wider window for explicit user pull-to-refresh.
    static let manualRefreshLookbackDays = 90

    /// Narrow window for realtime listener bootstrap / catch-up.
    static let realtimeLookbackDays = 7

    // MARK: - Throttles

    /// Minimum interval between cloud profile refresh attempts for the same UID.
    static let profileRefreshThrottleSeconds = 30

    /// Minimum interval between foreground cross-device refresh runs for the same UID.
    static let foregroundRefreshThrottleSeconds = 30

    /// Debounce interval for coalescing rapid realtime snapshot events.
    static let realtimeDebounceMilliseconds = 500

    // MARK: - Timeouts (seconds)

    /// Foreground refresh should finish quickly so tabs stay responsive.
    static let maximumForegroundRefreshSeconds = 12

    /// Manual refresh may pull more history and can run slightly longer.
    static let maximumManualRefreshSeconds = 20

    // MARK: - Behavioral guarantees

    /// Upload local pending mutations before pulling remote changes.
    static let uploadsLocalChangesBeforePull = true

    /// Phase 3 merge policy must skip or conflict on newer local pending edits — never overwrite.
    static let preservesLocalNewerUnsyncedEdits = true

    /// Remote documents must match the active signed-in UID before merge.
    static let requiresMatchingSessionUID = true

    // MARK: - Scope exclusions

    /// Cross-device sync never uploads or downloads raw meal image bytes — optional `imageUrl` strings only.
    static let includesRawMealImages = false

    /// Cross-device sync never uploads or downloads raw HealthKit samples.
    static let includesRawHealthKitData = false

    // MARK: - Mode helpers

    static func pullLookbackDays(for mode: CrossDeviceSyncMode) -> Int {
        switch mode {
        case .foregroundRefresh, .afterRemoteChange:
            return foregroundPullLookbackDays
        case .manualRefresh:
            return manualRefreshLookbackDays
        case .realtimeListener:
            return realtimeLookbackDays
        case .backgroundRefresh:
            return manualRefreshLookbackDays
        }
    }

    static func maximumRefreshSeconds(for mode: CrossDeviceSyncMode) -> TimeInterval {
        switch mode {
        case .foregroundRefresh, .realtimeListener, .afterRemoteChange, .backgroundRefresh:
            return TimeInterval(maximumForegroundRefreshSeconds)
        case .manualRefresh:
            return TimeInterval(maximumManualRefreshSeconds)
        }
    }

    static func realtimeDebounceInterval() -> Duration {
        .milliseconds(realtimeDebounceMilliseconds)
    }

    static func profileRefreshThrottleInterval() -> TimeInterval {
        TimeInterval(profileRefreshThrottleSeconds)
    }

    static func foregroundRefreshThrottleInterval() -> TimeInterval {
        TimeInterval(foregroundRefreshThrottleSeconds)
    }

    /// Whether the given mode should drain the upload outbox before any remote pull.
    static func shouldUploadBeforePull(for mode: CrossDeviceSyncMode) -> Bool {
        switch mode {
        case .foregroundRefresh, .manualRefresh, .realtimeListener, .backgroundRefresh, .afterRemoteChange:
            return uploadsLocalChangesBeforePull
        }
    }

    /// Whether merge may apply a remote document for the session UID.
    static func mayApplyRemoteDocument(documentUserId: String, sessionUID: String) -> Bool {
        guard requiresMatchingSessionUID else { return true }
        let normalizedDocumentUserId = documentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSessionUID = sessionUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDocumentUserId.isEmpty, !normalizedSessionUID.isEmpty else { return false }
        return normalizedDocumentUserId == normalizedSessionUID
    }
}
