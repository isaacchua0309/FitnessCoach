//
//  AIUsageMetadata.swift
//  Fitness Coach
//
//  FitPilot AI — Optional token/usage metadata returned by the AI backend.
//

import Foundation

struct AIUsageMetadata: Codable, Equatable, Sendable {
    var promptTokens: Int?
    var completionTokens: Int?
    var totalTokens: Int?
    var model: String?
}
