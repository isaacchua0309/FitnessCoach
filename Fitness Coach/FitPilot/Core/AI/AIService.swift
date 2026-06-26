//
//  AIService.swift
//  Fitness Coach
//
//  FitPilot AI — The AI boundary.
//
//  AIService parses, estimates, and explains. It returns structured drafts and
//  intents only. It does NOT import SwiftData, access ModelContext, call app
//  services (Food/Water/Weight/DailyLog/Workout), or own final arithmetic.
//  Validation and mutation happen elsewhere.
//

import Foundation

protocol AIServiceProtocol: Sendable {
    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult
    func estimateFood(prompt: String, context: AIContext) async throws -> AIFoodEstimateResponse
    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse
    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse
    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand
    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand
    func generateDailyReview(context: AIContext) async throws -> AICoachResponse
    func generateDailyReviewText(input: DailyReviewAIInput, context: AIContext) async throws -> AICoachResponse
    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand
}

final class AIService: AIServiceProtocol {

    private let llmClient: LLMClient
    private let commandParser: AICommandParser

    init(llmClient: LLMClient) {
        self.llmClient = llmClient
        self.commandParser = AICommandParser(llmClient: llmClient)
    }

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        let request = AICoachIntentClassificationRequest(
            text: text,
            context: context,
            modelName: config.cheapClassifierModel,
            modelConfig: config
        )
        do {
            return try await llmClient.classifyCoachIntent(request: request).intentResult
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func estimateFood(prompt: String, context: AIContext) async throws -> AIFoodEstimateResponse {
        let request = AIFoodEstimateRequest(text: prompt, context: context)
        do {
            return try await llmClient.estimateFood(request: request)
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult? = nil,
        tier: CoachModelTier = .cheap
    ) async throws -> AICoachResponse {
        let request = AIMealAdviceRequest(
            question: prompt,
            context: context,
            intentResult: intentResult,
            modelTier: tier,
            modelName: CoachModelConfig.default.modelName(for: tier)
        )
        do {
            return try await llmClient.generateMealAdvice(request: request).response
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        let request = AIWorkoutParseRequest(text: prompt, context: context)
        do {
            return try await llmClient.parseWorkout(request: request)
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        let request = AIEditDeleteParseRequest(text: prompt, context: context)
        do {
            let response = try await llmClient.parseEditOrDelete(request: request)
            return try validated(response.parsedCommand)
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        let request = AIMultiActionParseRequest(text: prompt, context: context)
        do {
            let response = try await llmClient.parseMultiAction(request: request)
            return try validated(response.parsedCommand)
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        guard let summary = context.todaySummary else {
            throw AIServiceError.validationFailed("Missing today summary for daily review.")
        }

        let input = DailyReviewAIInput(
            date: context.date,
            calorieTarget: summary.calorieTarget,
            caloriesConsumed: summary.caloriesConsumed,
            caloriesRemaining: summary.caloriesRemaining,
            isOverCalorieTarget: summary.caloriesRemaining < 0,
            proteinTarget: summary.proteinTarget,
            proteinConsumed: summary.proteinConsumed,
            proteinRemaining: summary.proteinRemaining,
            hasMetProteinTarget: summary.proteinRemaining <= 0,
            carbsTarget: summary.carbsTarget,
            carbsConsumed: summary.carbsConsumed,
            carbsRemaining: summary.carbsRemaining,
            fatTarget: summary.fatTarget,
            fatConsumed: summary.fatConsumed,
            fatRemaining: summary.fatRemaining,
            waterTargetMl: summary.waterTargetMl,
            waterConsumedMl: summary.waterConsumedMl,
            waterRemainingMl: summary.waterRemainingMl,
            hasMetWaterTarget: summary.waterRemainingMl <= 0,
            weightKg: summary.weightKg,
            latestWeightKg: summary.weightKg,
            steps: summary.steps,
            workoutCount: summary.workoutsToday,
            workoutCaloriesBurned: summary.workoutCaloriesBurned,
            foodEntryCount: summary.recentMeals.count,
            lowConfidenceFoodCount: 0,
            topProteinFoodNames: summary.recentMeals,
            deterministicNotes: []
        )
        return try await generateDailyReviewText(input: input, context: context)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        let request = AIDailyReviewRequest(input: input, context: context)
        do {
            return try await llmClient.generateDailyReview(request: request).response
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        try await commandParser.parseCommand(text, context: context)
    }

    private func validated(_ command: AIParsedCommand) throws -> AIParsedCommand {
        if case .invalid(let reason) = AIResponseValidator.validate(command) {
            throw AIServiceError.validationFailed(reason)
        }
        return command
    }
}
