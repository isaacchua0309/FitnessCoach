//
//  CoachActionResult.swift
//  Fitness Coach
//
//  Outcome of a Coach handler — assistant message plus optional pending confirmation.
//

import Foundation

struct CoachActionResult: Equatable {
    let message: String
    let structuredContent: CoachStructuredMessageContent?
    let pendingConfirmation: CoachPendingConfirmation?

    static func message(_ text: String) -> CoachActionResult {
        CoachActionResult(message: text, structuredContent: nil, pendingConfirmation: nil)
    }

    static func structured(_ content: CoachStructuredMessageContent, accessibilityText: String) -> CoachActionResult {
        CoachActionResult(message: accessibilityText, structuredContent: content, pendingConfirmation: nil)
    }

    static func pending(_ confirmation: CoachPendingConfirmation, message: String) -> CoachActionResult {
        CoachActionResult(message: message, structuredContent: nil, pendingConfirmation: confirmation)
    }
}
