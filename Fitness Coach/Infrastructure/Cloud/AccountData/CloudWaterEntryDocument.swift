//
//  CloudWaterEntryDocument.swift
//  Fitness Coach
//
//  Forma — Firestore DTO for water log entries.
//

import Foundation

struct CloudWaterEntryDocument: Codable, Equatable, Sendable, CloudAccountDataDocument {
    var id: String
    var userId: String
    var dailyLogId: String
    var localDate: String
    var amountMl: Int
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var deviceId: String?
    var source: String?
    var mutationId: String?
}
