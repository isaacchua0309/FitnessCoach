//
//  CloudSyncMetadataDocument.swift
//  Fitness Coach
//
//  Forma — Firestore DTO for account sync metadata (`syncMetadata/current`).
//

import Foundation

/// Singleton sync metadata document for nutrition account persistence.
struct CloudSyncMetadataDocument: Codable, Equatable, Sendable, CloudAccountDataDocument {
    var userId: String
    var schemaVersion: Int
    var lastFullPullAt: Date?
    var lastSuccessfulPushAt: Date?
    var lastSuccessfulPullAt: Date?
    var lastKnownServerUpdatedAt: Date?
    var lastMigrationAt: Date?
    var lastDeviceId: String?
    var clientVersion: String?
    var updatedAt: Date
}
