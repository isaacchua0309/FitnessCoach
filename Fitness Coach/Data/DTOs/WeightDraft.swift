//
//  WeightDraft.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing input for logging weight.
//

import Foundation

struct WeightDraft: Codable, Equatable, Sendable {
    var weightKg: Double
    var note: String?
}
