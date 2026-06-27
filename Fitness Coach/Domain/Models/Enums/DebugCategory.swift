//
//  DebugCategory.swift
//  Fitness Coach
//
//  FitPilot AI — Core domain enums.
//

import Foundation

enum DebugCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case aiParsingFailure
    case foodEstimationFailure
    case persistenceFailure
    case calculationValidationFailure
    case reviewGenerationFailure
    case healthKitSyncFailure
    case cloudSyncFailure
}
