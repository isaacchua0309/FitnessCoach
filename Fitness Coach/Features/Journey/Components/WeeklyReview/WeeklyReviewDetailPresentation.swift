//
//  WeeklyReviewDetailPresentation.swift
//  Fitness Coach
//
//  Forma — Sheet presentation wrapper for weekly review detail.
//

import Foundation

struct WeeklyReviewDetailPresentation: Identifiable, Equatable {
    let state: WeeklyReviewDetailState

    var id: String {
        "\(state.dateRangeLabel)-\(state.title)"
    }
}
