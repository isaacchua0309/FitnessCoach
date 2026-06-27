//
//  DebugRecord.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct DebugRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var category: DebugCategory
    var message: String
    var context: [String: String]
    var createdAt: Date
}
