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
            text: "new day 90.15",
            createdAt: Date(timeIntervalSinceNow: -240),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        ),
        ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "Started a new day and logged your weight as 90.15 kg.",
            createdAt: Date(timeIntervalSinceNow: -235),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        ),
        ChatMessage(
            id: UUID(),
            role: .user,
            text: "log chicken breast 413 calories 78 protein 0 carbs 4 fat",
            createdAt: Date(timeIntervalSinceNow: -180),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        ),
        ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "Logged chicken breast: 413 kcal, 78g protein, 0g carbs, 4g fat. Today: 413 / 1800 kcal.",
            createdAt: Date(timeIntervalSinceNow: -175),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        )
    ]
}
