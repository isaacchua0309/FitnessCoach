//
//  TodayTransientFeedback.swift
//  Fitness Coach
//
//  Forma — Non-blocking snackbar payload for Today mutations.
//

import Foundation

struct TodayTransientFeedback: Equatable, Sendable {
    enum Style: Equatable, Sendable {
        case success
        case error
    }

    var message: String
    var style: Style

    var autoDismissNanoseconds: UInt64 {
        switch style {
        case .success: 2_000_000_000
        case .error: 3_000_000_000
        }
    }
}
