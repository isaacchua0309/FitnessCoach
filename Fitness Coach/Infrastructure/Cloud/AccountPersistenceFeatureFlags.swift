//
//  AccountPersistenceFeatureFlags.swift
//  Fitness Coach
//
//  Forma — Account persistence rollout flags (Phase 2 foundation / Phase 3 sync).
//
//  Phase 3: `AccountSyncCoordinator` reads these flags. Pull and restore UX remain gated.
//

import Foundation

enum AccountPersistenceFeatureFlags {

    /// Cloud DTOs, paths, mappers, and remote store client are available.
    static let cloudSchemaEnabled = true

    /// Master switch for `AccountSyncCoordinator` upload/pull orchestration.
    static let syncEngineEnabled = true

    /// Upload due outbox mutations during coordinated sync runs.
    static let uploadPendingMutationsEnabled = true

    /// Bounded recent pull (default 90 days). Not full account restore.
    static let pullRecentDataEnabled = false

    /// Phase 4 user-facing restore on login/reinstall.
    static let restoreOnLoginEnabled = false

    /// Phase 5 realtime cross-device listeners.
    static let realtimeCrossDeviceSyncEnabled = false
}
