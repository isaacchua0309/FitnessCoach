//
//  WeeklyReviewDetailPresentation.swift
//  Fitness Coach
//
//  Forma — Sheet presentation wrapper for weekly progress detail.
//

import Foundation

struct WeeklyReviewDetailPresentation: Identifiable, Equatable {
    let detail: WeeklyProgressDetailState

    var id: String {
        detail.unified.id
    }

    init(detail: WeeklyProgressDetailState) {
        self.detail = detail
    }
}
