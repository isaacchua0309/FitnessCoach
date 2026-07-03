//
//  WorkoutIntelligenceEngine.swift
//  Fitness Coach
//
//  Forma — Workout detection and summarization for Health Intelligence.
//

import Foundation

protocol WorkoutIntelligenceEngineing: Sendable {
    func workoutSummary(
        for date: Date,
        samples: [HealthNormalizedSample],
        calendar: Calendar
    ) async -> WorkoutSummary?
}

struct WorkoutIntelligenceEngine: WorkoutIntelligenceEngineing {

    func workoutSummary(
        for date: Date,
        samples: [HealthNormalizedSample],
        calendar: Calendar = .current
    ) async -> WorkoutSummary? {
        // TODO: Derive workout count, primary activity, and intensity from normalized workout samples.
        _ = (date, samples, calendar)
        return nil
    }
}
