//
//  CloudWeightEntryDocument.swift
//  Fitness Coach
//
//  Forma — Firestore DTO for weight log entries.
//

import Foundation

struct CloudWeightEntryDocument: Codable, Equatable, Sendable, CloudAccountDataDocument {
    var id: String
    var userId: String
    var localDate: String
    var weightKg: Double
    var note: String?
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var deviceId: String?
    var source: String?
    var mutationId: String?
}
