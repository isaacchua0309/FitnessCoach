//
//  CoachLayoutPreviewFixtures.swift
//  Fitness Coach
//
//  FitPilot AI — Seeded Coach chat state for layout previews and regression harnesses.
//

import Foundation

enum CoachLayoutPreviewFixtures {

    static let mealPhotoUserMessageID = UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!
    static let nutritionEstimateMessageID = UUID(uuidString: "A1000002-0000-4000-8000-000000000002")!

    static let pendingFoodDraft = AIFoodConfirmationDraft(
        originalText: "How many calories in this lunch bowl?",
        assistantMessage: nil,
        mealDraft: FoodLogDraft(
            displayName: "Chicken rice bowl",
            mealType: .lunch,
            components: [
                FoodComponent(
                    name: "Chicken rice bowl",
                    quantity: 1,
                    unit: "bowl",
                    calories: 510,
                    protein: 35,
                    carbs: 58,
                    fat: 14,
                    confidence: .medium
                )
            ],
            confidence: .medium,
            source: .aiPhotoEstimate
        ),
        confidence: .medium,
        requiresConfirmation: true,
        relatedPhotoUserMessageID: mealPhotoUserMessageID
    )

    static var pendingConfirmation: CoachPendingConfirmation {
        .food(pendingFoodDraft)
    }

    static var messages: [ChatMessage] {
        var transcript: [ChatMessage] = [
            ChatMessage(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000000")!,
                role: .assistant,
                text: "Here is what I have logged so far today. Ask me anything about your meals or workouts.",
                createdAt: Date(timeIntervalSinceNow: -600)
            )
        ]

        if let photoMessage = mealPhotoUserMessage {
            transcript.append(photoMessage)
        }
        if let estimateMessage = nutritionEstimateAssistantMessage {
            transcript.append(estimateMessage)
        }
        if let analysisMessage = mealPhotoAssistantMessage {
            transcript.append(analysisMessage)
        }

        return transcript
    }

    static var mealPhotoUserMessage: ChatMessage? {
        guard let attachment = CoachPreviewData.sampleMealPhotoAttachment else { return nil }
        return ChatMessage(
            id: mealPhotoUserMessageID,
            role: .user,
            text: "How many calories in this?",
            createdAt: Date(timeIntervalSinceNow: -120),
            imageAttachment: attachment
        )
    }

    static var mealPhotoAssistantMessage: ChatMessage? {
        ChatMessage(
            id: UUID(uuidString: "A1000003-0000-4000-8000-000000000003")!,
            role: .assistant,
            text: """
            From your meal photo, I'd estimate chicken rice bowl:
            About 510 kcal · 35g protein · 58g carbs · 14g fat

            Review this photo estimate before logging.
            """,
            createdAt: Date(timeIntervalSinceNow: -90),
            photoAnalysisLink: ChatMessagePhotoAnalysisLink(
                sessionID: UUID(uuidString: "A1000004-0000-4000-8000-000000000004")!,
                relatedUserMessageID: mealPhotoUserMessageID,
                kind: .result
            )
        )
    }

    static var nutritionEstimateAssistantMessage: ChatMessage? {
        ChatMessage(
            id: nutritionEstimateMessageID,
            role: .assistant,
            text: "Chicken rice bowl estimate card",
            createdAt: Date(timeIntervalSinceNow: -150),
            structuredContent: .nutritionEstimate(nutritionEstimateCardState)
        )
    }

    static var nutritionEstimateCardState: NutritionEstimateCardState {
        NutritionEstimateCardState(
            id: UUID(uuidString: "A1000005-0000-4000-8000-000000000005")!,
            foodName: "Chicken rice bowl",
            displayEmoji: "🍗",
            servingDescription: "1 bowl",
            caloriesDisplay: "510 kcal",
            proteinDisplay: "Protein 35g",
            carbsDisplay: "Carbs 58g",
            fatDisplay: "Fat 14g",
            confidenceTitle: "Medium confidence",
            confidenceSubtitle: "Photo-based estimate",
            coachSummary: "Fits within your lunch target.",
            coachTip: nil,
            caveats: [],
            todayContext: NutritionEstimateTodayContext(
                caloriesAfterLine: "Calories after this: 1,420 / 2,086 kcal",
                caloriesRemainingLine: "Remaining: 666 kcal",
                proteinLine: "Protein: 112 / 198g"
            ),
            suggestedActions: [
                NutritionSuggestedAction(title: "Log Meal", type: .logMeal)
            ],
            sourceType: .common,
            confidenceLevel: .medium,
            hasMacros: true,
            hasTodayContext: true,
            logMealPayload: nil
        )
    }
}
