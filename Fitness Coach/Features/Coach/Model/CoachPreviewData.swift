//
//  CoachPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static chat messages for Coach UI previews only.
//

import Foundation
import UIKit

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

    static var sampleMealPhotoAttachment: ChatMessageImageAttachment? {
        guard let data = UIImage(systemName: "fork.knife")?
            .jpegData(compressionQuality: 0.9) else {
            return nil
        }
        return ChatMessageImageAttachment.fromJPEG(data, source: .library)
    }

    static var mealPhotoUserMessage: ChatMessage? {
        guard let attachment = sampleMealPhotoAttachment else { return nil }
        return ChatMessage.userMealPhoto(caption: "Lunch bowl", attachment: attachment)
    }

    static var mealPhotoAssistantMessage: ChatMessage? {
        guard let userMessage = mealPhotoUserMessage else { return nil }
        return ChatMessage.assistantPhotoAnalysisResult(
            text: """
            From your meal photo, I'd estimate lunch bowl:
            About 420 kcal · 28g protein · 35g carbs · 14g fat

            Review this photo estimate before logging.
            """,
            sessionID: UUID(),
            relatedUserMessageID: userMessage.id
        )
    }

    static var mealPhotoFailureMessage: ChatMessage? {
        guard let userMessage = mealPhotoUserMessage else { return nil }
        return ChatMessage.assistantPhotoAnalysisFailure(
            text: "I couldn't analyze that photo right now. Coach is temporarily unavailable. Please try again later. You can try again or log manually.",
            sessionID: UUID(),
            relatedUserMessageID: userMessage.id
        )
    }
}
