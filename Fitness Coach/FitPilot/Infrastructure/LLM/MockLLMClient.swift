//
//  MockLLMClient.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic LLM client for local development and previews.
//
//  This returns predictable responses for known inputs so the Coach AI fallback
//  can be exercised without a real backend. Mock estimates are development-only
//  and must not be treated as production nutrition truth.
//

import Foundation

final class MockLLMClient: LLMClient {

    init() {}

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        let text = request.text.lowercased()

        if text.contains("scoop"), text.contains("whey") {
            let draft = FoodDraft(
                mealType: nil,
                name: "ON whey protein",
                quantity: 3,
                unit: "scoops",
                calories: 360,
                protein: 72,
                carbs: 9,
                fat: 4.5,
                fiber: nil,
                sodium: nil,
                source: .aiTextEstimate,
                confidence: .high,
                imageUrl: nil,
                notes: nil
            )
            let action = AICommandAction(type: .logFood, foodDraft: draft)
            let command = AIParsedCommand(
                originalText: request.text,
                intent: .logFood,
                actions: [action],
                confidence: .high,
                requiresConfirmation: true,
                assistantMessage: "I read this as 3 scoops of whey protein (about 360 kcal, 72g protein).",
                reasoningSummary: "Known supplement with standard per-scoop macros."
            )
            return AIParseCommandResponse(parsedCommand: command)
        }

        if text.contains("chicken rice") || text.contains("rice") {
            let draft = FoodDraft(
                mealType: nil,
                name: "Chicken rice",
                quantity: 1,
                unit: "plate",
                calories: 650,
                protein: 35,
                carbs: 75,
                fat: 20,
                fiber: nil,
                sodium: nil,
                source: .aiTextEstimate,
                confidence: .medium,
                imageUrl: nil,
                notes: nil
            )
            let action = AICommandAction(type: .logFood, foodDraft: draft)
            let command = AIParsedCommand(
                originalText: request.text,
                intent: .logFood,
                actions: [action],
                confidence: .medium,
                requiresConfirmation: true,
                assistantMessage: "I estimated chicken rice at around 650 kcal. Portion sizes vary, so please confirm.",
                reasoningSummary: "Common dish with variable portion size."
            )
            return AIParseCommandResponse(parsedCommand: command)
        }

        if text.contains("should i eat") || text.contains("what should i eat") || text.contains("advice") {
            let command = AIParsedCommand(
                originalText: request.text,
                intent: .mealAdvice,
                actions: [AICommandAction(type: .mealAdvice, adviceQuestion: request.text)],
                confidence: .medium,
                requiresConfirmation: false,
                assistantMessage: "Here is some quick guidance.",
                reasoningSummary: "Open-ended nutrition question."
            )
            return AIParseCommandResponse(parsedCommand: command)
        }

        let unknown = AIParsedCommand(
            originalText: request.text,
            intent: .unknown,
            actions: [],
            confidence: .low,
            requiresConfirmation: true,
            assistantMessage: "I am not sure how to handle that yet.",
            reasoningSummary: "No known pattern matched."
        )
        return AIParseCommandResponse(parsedCommand: unknown)
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        let draft = FoodDraft(
            mealType: nil,
            name: request.text,
            quantity: nil,
            unit: nil,
            calories: 500,
            protein: 25,
            carbs: 60,
            fat: 18,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .low,
            imageUrl: nil,
            notes: nil
        )
        return AIFoodEstimateResponse(
            foodDrafts: [draft],
            confidence: .low,
            requiresConfirmation: true,
            assistantMessage: "This is a rough estimate. Please confirm or edit before logging."
        )
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        let response = AICoachResponse(
            message: "If it fits your remaining calories and protein for the day, a moderate portion is fine. "
                + "Aim to keep protein high and balance the rest across your week.",
            confidence: .medium,
            followUpSuggestions: ["Log it with explicit macros", "Check status"]
        )
        return AIMealAdviceResponse(response: response)
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        let response = AICoachResponse(
            message: "Solid effort today. You stayed close to your targets. "
                + "Tomorrow, try to log meals a little earlier to pace your intake.",
            confidence: .medium
        )
        return AIDailyReviewResponse(response: response)
    }
}
