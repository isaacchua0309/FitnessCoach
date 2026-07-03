//
//  PlanAnalyticsContextBuilder.swift
//  Fitness Coach
//
//  Forma — Safe Plan analytics snapshots and buckets (no PII).
//

import Foundation

struct PlanAnalyticsSnapshot: Equatable, Sendable {
    var planType: String
    var confidenceBucket: String
    var appleHealthConnected: Bool
    var hasRecentWeighIn: Bool
    var hasEnoughFoodLogs: Bool
}

enum PlanAnalyticsContextBuilder {

    static func snapshot(
        from state: PlanDashboardState,
        healthConnected: Bool
    ) -> PlanAnalyticsSnapshot {
        PlanAnalyticsSnapshot(
            planType: planType(from: state.status.classification),
            confidenceBucket: confidenceBucket(from: state.confidence.estimateBucket),
            appleHealthConnected: healthConnected,
            hasRecentWeighIn: hasRecentWeighIn(from: state.confidence),
            hasEnoughFoodLogs: hasEnoughFoodLogs(from: state.confidence)
        )
    }

    static func planType(from classification: PlanStrategyClassification) -> String {
        switch classification {
        case .aggressiveCut:
            return "aggressive_cut"
        case .moderateCut, .gentleCut:
            return "moderate_cut"
        case .maintenance:
            return "maintenance"
        case .leanGain, .rebuild:
            return "lean_gain"
        case .needsReview:
            return "needs_review"
        }
    }

    static func confidenceBucket(from bucket: PlanConfidenceEstimateBucket) -> String {
        bucket.rawValue
    }

    static func hasRecentWeighIn(from confidence: PlanConfidenceState) -> Bool {
        confidence.compactSignals.first { $0.id == "weighIn" }?.value
            == FormaProductCopy.PlanMissionControl.planConfidenceSignalYes
    }

    static func hasEnoughFoodLogs(from confidence: PlanConfidenceState) -> Bool {
        confidence.compactSignals.first { $0.id == "foodLogs" }?.value
            == FormaProductCopy.PlanMissionControl.planConfidenceSignalEnough
    }
}
