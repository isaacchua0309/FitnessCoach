//
//  DailyReviewRepository.swift
//  Fitness Coach
//
//  Domain protocols for daily review reads.
//

import Foundation

@MainActor
protocol DailyReviewReading: AnyObject {
    func getDailyReview(for date: Date) throws -> DailyReview?
}

extension ReviewService: DailyReviewReading {}
