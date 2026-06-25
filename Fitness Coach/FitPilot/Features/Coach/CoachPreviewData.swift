//
//  CoachPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static chat messages for Coach UI previews only.
//

import Foundation

enum CoachPreviewData {
    static let messages: [ChatMessage] = [
        ChatMessage(
            id: UUID(),
            role: .user,
            text: "weight 90.15",
            createdAt: Date(timeIntervalSinceNow: -240),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        ),
        ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "Logged your weight as 90.15 kg.",
            createdAt: Date(timeIntervalSinceNow: -235),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        ),
        ChatMessage(
            id: UUID(),
            role: .user,
            text: "Add 500ml water",
            createdAt: Date(timeIntervalSinceNow: -180),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        )
    ]

    static let confirmationMessage = ChatMessage(
        id: UUID(),
        role: .assistant,
        text: """
        Logged 500ml water.

        Water: 1,500 / 3,150ml
        Remaining: 1,650ml
        """,
        createdAt: Date(timeIntervalSinceNow: -175),
        relatedDailyLogId: nil,
        relatedEntryId: nil
    )
}
