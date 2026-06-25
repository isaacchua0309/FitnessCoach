//
//  WeightEntry.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct WeightEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var date: Date
    var weightKg: Double
    var note: String?
    var createdAt: Date
}
