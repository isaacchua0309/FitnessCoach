//
//  AccountPersistenceFeatureFlags.swift
//  Fitness Coach
//
//  Forma — Compile-time account persistence rollout flags (Phases 2–5).
//
//  **Owner:** Account persistence platform.
//  **Registry:** `Docs/Architecture/FeatureFlagRegistry.md` § Account persistence.
//
//  These are `static let` constants — not runtime A/B toggles. Do not disable sync,
//  restore, or cross-device refresh without the full account persistence regression suite.
//
//  Exposed read-through: `FormaAbTest.AccountPersistence.*`
//

import Foundation

enum AccountPersistenceFeatureFlags {

    /// Cloud DTOs, paths, mappers, and remote store client are available.
    /// Production default: `true`. Risk if disabled: no cloud schema or remote I/O.
    static let cloudSchemaEnabled = true

    /// Master switch for `AccountSyncCoordinator` upload/pull orchestration.
    /// Production default: `true`. Risk if disabled: no account sync.
    static let syncEngineEnabled = true

    /// Upload due outbox mutations during coordinated sync runs.
    /// Production default: `true`. Risk if disabled: local changes never reach cloud.
    static let uploadPendingMutationsEnabled = true

    /// Bounded recent pull (default 90 days). Not full account restore.
    /// Production default: `false` (intentionally off — restore/cross-device cover other paths).
    static let pullRecentDataEnabled = false

    /// Phase 4 user-facing restore on login/reinstall.
    /// Production default: `true`. Risk if disabled: no blocking restore UX on sign-in.
    static let restoreOnLoginEnabled = true

    /// Phase 5 bounded foreground cross-device refresh on app active.
    /// Production default: `true`. Risk if disabled: stale data after switching devices.
    static let foregroundCrossDeviceRefreshEnabled = true

    /// Phase 5 realtime cross-device listeners.
    /// Production default: `true`. Risk if disabled: delayed cross-device updates.
    static let realtimeCrossDeviceSyncEnabled = true

    /// Phase 5 explicit pull-to-refresh cross-device sync.
    /// Production default: `true`. Risk if disabled: manual refresh no-ops.
    static let manualRefreshEnabled = true
}
