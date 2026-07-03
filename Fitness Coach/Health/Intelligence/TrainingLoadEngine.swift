//
//  TrainingLoadEngine.swift
//  Fitness Coach
//
//  Forma — Rolling training load and strain metrics.
//

import Foundation

struct TrainingLoadSummary: Equatable, Sendable {
    var acuteLoad: Double
    var chronicLoad: Double
    var strainRatio: Double?

    static let empty = TrainingLoadSummary(
        acuteLoad: 0,
        chronicLoad: 0,
        strainRatio: nil
    )
}

protocol TrainingLoadEngineing: Sendable {
    func trainingLoad(
        for date: Date,
        samples: [HealthNormalizedSample],
        calendar: Calendar
    ) async -> TrainingLoadSummary
}

struct TrainingLoadEngine: TrainingLoadEngineing {

    func trainingLoad(
        for date: Date,
        samples: [HealthNormalizedSample],
        calendar: Calendar = .current
    ) async -> TrainingLoadSummary {
        // TODO: Compute acute/chronic load windows from workout duration and energy burn.
        _ = (date, samples, calendar)
        return .empty
    }
}
