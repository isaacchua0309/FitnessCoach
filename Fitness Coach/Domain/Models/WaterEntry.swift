//
//  WaterEntry.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct WaterEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var dailyLogId: UUID
    var amountMl: Int
    var createdAt: Date
}
