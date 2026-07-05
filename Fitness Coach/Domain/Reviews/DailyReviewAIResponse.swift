//
//  DailyReviewAIResponse.swift
//  Fitness Coach
//
//  Structured daily review copy returned by the AI boundary.
//

import Foundation

/// Field length limits for daily review coach copy.
enum DailyReviewContentContract {
    static let maxStatusSummaryLength = 120
    static let maxBestNextMoveLength = 140
    static let maxTomorrowFocusLength = 140
    static let maxDetailNoteLength = 100
}

struct DailyReviewAIResponse: Codable, Equatable, Sendable {
    var statusSummary: String
    var bestNextMove: String
    var tomorrowFocus: String?
    var missingSignals: [String]?
    var detailNote: String?

    init(
        statusSummary: String,
        bestNextMove: String,
        tomorrowFocus: String? = nil,
        missingSignals: [String]? = nil,
        detailNote: String? = nil
    ) {
        self.statusSummary = statusSummary
        self.bestNextMove = bestNextMove
        self.tomorrowFocus = tomorrowFocus
        self.missingSignals = missingSignals
        self.detailNote = detailNote
    }
}
