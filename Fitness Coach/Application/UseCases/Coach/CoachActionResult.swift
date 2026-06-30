//
//  CoachActionResult.swift
//  Fitness Coach
//
//  Outcome of a Coach handler — assistant message plus optional pending confirmation.
//

import Foundation

struct CoachActionResult: Equatable {
    let message: String
    let pendingConfirmation: CoachPendingConfirmation?

    static func message(_ text: String) -> CoachActionResult {
        CoachActionResult(message: text, pendingConfirmation: nil)
    }

    static func pending(_ confirmation: CoachPendingConfirmation, message: String) -> CoachActionResult {
        CoachActionResult(message: message, pendingConfirmation: confirmation)
    }
}
