//
//  HealthSummarySyncSchemaVersion.swift
//  Fitness Coach
//
//  Forma — Schema version constants for remote Health Summary Sync payloads.
//
//  Increment `current` only for breaking contract changes. Additive optional fields
//  may ship under the same version when Firestore readers remain tolerant.
//

import Foundation

enum HealthSummarySyncSchemaVersion {

    /// Per-document payload schema version written to Firestore.
    static let current = 1

    /// Client sync mapper version tracked in `HealthSyncMetadataPayload`.
    static let clientMapperVersion = 1
}
