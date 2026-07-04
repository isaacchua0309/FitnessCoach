//
//  CloudAccountDataEnvelope.swift
//  Fitness Coach
//
//  Forma — Shared schema metadata for account-backed Firestore documents (Phase 2).
//
//  Privacy: never include raw meal images, coach chat payloads, or HealthKit samples.
//

import Foundation

/// Standard account-backed document fields written on log payloads.
struct CloudAccountDataEnvelope: Codable, Equatable, Sendable {
    var id: String
    var userId: String
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var deviceId: String?
    var source: String?
}

/// Minimum fields required for owner validation before Firestore writes.
protocol CloudAccountDataDocument: Equatable, Sendable {
    var userId: String { get }
    var schemaVersion: Int { get }
    var updatedAt: Date { get }
}

extension CloudAccountDataEnvelope {

    static func make(
        id: String,
        userId: String,
        createdAt: Date,
        updatedAt: Date,
        deviceId: String? = nil,
        source: String? = AccountDataCloudSchema.clientSource,
        deletedAt: Date? = nil,
        schemaVersion: Int = AccountDataCloudSchema.currentSchemaVersion
    ) -> CloudAccountDataEnvelope {
        CloudAccountDataEnvelope(
            id: id,
            userId: userId,
            schemaVersion: schemaVersion,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            deviceId: deviceId,
            source: source
        )
    }
}
