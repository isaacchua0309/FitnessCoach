//
//  AccountPersistenceFeatureFlags.swift
//  Fitness Coach
//
//  Forma — Account persistence rollout flags (Phase 2 foundation / Phase 3 sync).
//
//  Phase 2: cloud schema + remote store are constructible but dormant.
//  Phase 3: enable syncEngineEnabled when AccountSyncEngine is wired.
//

import Foundation

enum AccountPersistenceFeatureFlags {

    /// Cloud DTOs, paths, mappers, and remote store client are available.
    static let cloudSchemaEnabled = true

    /// Background upload/outbox sync. Remains off until Phase 3.
    static let syncEngineEnabled = false

    /// Restore local logs from cloud on login/reinstall. Remains off until Phase 3.
    static let restoreOnLoginEnabled = false
}
