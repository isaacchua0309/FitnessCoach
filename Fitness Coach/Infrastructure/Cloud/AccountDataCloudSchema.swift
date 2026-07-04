//
//  AccountDataCloudSchema.swift
//  Fitness Coach
//
//  Forma — Canonical Firestore field names and schema version for account-backed data (Phase 2).
//

import Foundation

/// Shared Firestore document field keys and schema version for account persistence.
enum AccountDataCloudSchema {

    static let currentSchemaVersion = 1

    /// Value written to the `source` field on nutrition cloud documents.
    static let clientSource = "ios_forma"

    static let userId = "userId"
    static let schemaVersion = "schemaVersion"
    static let createdAt = "createdAt"
    static let updatedAt = "updatedAt"
    static let deletedAt = "deletedAt"
    static let deviceId = "deviceId"
    static let source = "source"
}
