//
//  HealthNextBestActionEngine.swift
//  Fitness Coach
//
//  Forma — Health Intelligence next-best-action recommendations.
//
//  Note: Renamed from `NextBestActionEngine` to avoid conflict with
//  `Features/Today/Model/NextBestActionEngine` (Today Mission Control).
//

import Foundation

protocol HealthNextBestActionEngineing: Sendable {
    func nextBestAction(
        for date: Date,
        snapshot: HealthIntelligenceSnapshot
    ) async -> NextBestAction
}

struct HealthNextBestActionEngine: HealthNextBestActionEngineing {

    func nextBestAction(
        for date: Date,
        snapshot: HealthIntelligenceSnapshot
    ) async -> NextBestAction {
        // TODO: Rank recovery, nutrition, and training actions from snapshot signals.
        _ = (date, snapshot)
        return .none
    }
}