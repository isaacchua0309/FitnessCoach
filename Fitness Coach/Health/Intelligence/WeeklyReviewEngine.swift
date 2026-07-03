//
//  WeeklyReviewEngine.swift
//  Fitness Coach
//
//  Forma — Weekly health and training review synthesis.
//

import Foundation

protocol WeeklyReviewEngineing: Sendable {
    func weeklyReview(
        endingOn date: Date,
        samples: [HealthNormalizedSample],
        calendar: Calendar
    ) async -> WeeklyHealthReview?
}

struct WeeklyReviewEngine: WeeklyReviewEngineing {

    func weeklyReview(
        endingOn date: Date,
        samples: [HealthNormalizedSample],
        calendar: Calendar = .current
    ) async -> WeeklyHealthReview? {
        // TODO: Aggregate seven-day trends and produce review headline + narrative.
        _ = (date, samples, calendar)
        return nil
    }
}
