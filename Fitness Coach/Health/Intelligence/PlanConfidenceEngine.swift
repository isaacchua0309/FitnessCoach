//
//  PlanConfidenceEngine.swift
//  Fitness Coach
//
//  Forma — Plan adherence confidence informed by health signal quality.
//

import Foundation

protocol PlanConfidenceEngineing: Sendable {
    func planConfidence(
        for date: Date,
        recovery: RecoverySummary,
        activity: ActivitySummary,
        trainingLoad: TrainingLoadSummary
    ) async -> PlanHealthConfidence
}

struct PlanConfidenceEngine: PlanConfidenceEngineing {

    func planConfidence(
        for date: Date,
        recovery: RecoverySummary,
        activity: ActivitySummary,
        trainingLoad: TrainingLoadSummary
    ) async -> PlanHealthConfidence {
        // TODO: Score plan confidence from logging consistency, health connectivity, and load trends.
        _ = (date, recovery, activity, trainingLoad)
        return .unknown
    }
}
