//
//  AIService.swift
//  Fitness Coach
//
//  FitPilot AI — The AI boundary.
//

import Foundation
import OSLog

protocol AIServiceProtocol: Sendable {
    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult
    func estimateFood(
        prompt: String,
        context: AIContext,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse
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
    #if DEBUG
    private static let debugLogger = Logger(subsystem: "Forma", category: "CoachAI")
    #endif

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
        return try await traced(method: "classifyCoachIntent") {
            try await llmClient.classifyCoachIntent(request: request).intentResult
        }
    }

    func estimateFood(
        prompt: String,
        context: AIContext,
        imageJPEGData: Data? = nil
    ) async throws -> AIFoodEstimateResponse {
        try await traced(method: "estimateFood") {
            let initialRequest = AIFoodEstimateRequest(
                text: prompt,
                context: context,
                imageJPEGBase64: imageJPEGData.map { $0.base64EncodedString() }
            )
            var response = try await llmClient.estimateFood(request: initialRequest)

            let validation = FoodEstimateResponseValidator.validate(response: response, prompt: prompt)
            guard case .invalid(let errors) = validation else {
                return response
            }

            FormaPipelineTracer.event(
                stage: .aiTask,
                level: .warn,
                message: "Food estimate failed client validation; retrying once",
                fields: ["errors": errors.joined(separator: " | ")]
            )

            let repairRequest = AIFoodEstimateRequest(
                text: FoodEstimateResponseValidator.repairPrompt(original: prompt, errors: errors),
                context: context,
                imageJPEGBase64: imageJPEGData.map { $0.base64EncodedString() },
                repairErrors: errors
            )
            response = try await llmClient.estimateFood(request: repairRequest)

            let secondValidation = FoodEstimateResponseValidator.validate(response: response, prompt: prompt)
            if case .invalid(let secondErrors) = secondValidation {
                FormaPipelineTracer.event(
                    stage: .aiTask,
                    level: .warn,
                    message: "Food estimate still invalid after client repair retry",
                    fields: ["errors": secondErrors.joined(separator: " | ")]
                )
                throw AIServiceError.validationFailed(secondErrors.joined(separator: " | "))
            }

            return response
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
        return try await traced(method: "generateMealAdvice") {
            try await llmClient.generateMealAdvice(request: request).response
        }
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        let request = AIWorkoutParseRequest(text: prompt, context: context)
        return try await traced(method: "parseWorkout") {
            try await llmClient.parseWorkout(request: request)
        }
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        let request = AIEditDeleteParseRequest(text: prompt, context: context)
        return try await traced(method: "parseEditOrDelete") {
            let response = try await llmClient.parseEditOrDelete(request: request)
            return try validated(response.parsedCommand)
        }
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        let request = AIMultiActionParseRequest(text: prompt, context: context)
        return try await traced(method: "parseMultiAction") {
            let response = try await llmClient.parseMultiAction(request: request)
            return try validated(response.parsedCommand)
        }
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        guard let summary = context.todaySummary else {
            throw AIServiceError.validationFailed("Missing today summary for daily review.")
        }

        let input = TodayAISummaryMapper.dailyReviewAIInput(
            from: summary,
            date: context.date
        )
        return try await generateDailyReviewText(input: input, context: context)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        let request = AIDailyReviewRequest(input: input, context: context)
        return try await traced(method: "generateDailyReview") {
            try await llmClient.generateDailyReview(request: request).response
        }
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        try await traced(method: "parseCommand") {
            try await commandParser.parseCommand(text, context: context)
        }
    }

    private func validated(_ command: AIParsedCommand) throws -> AIParsedCommand {
        if case .invalid(let reason) = AIResponseValidator.validate(command) {
            throw AIServiceError.validationFailed(reason)
        }
        return command
    }

    private func traced<T>(
        method: String,
        work: () async throws -> T
    ) async throws -> T {
        let started = Date()
        FormaPipelineTracer.event(
            stage: .aiTask,
            level: .debug,
            message: "AIService call started",
            fields: ["method": method]
        )

        do {
            let result = try await work()
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            FormaPipelineTracer.event(
                stage: .aiTask,
                level: .info,
                message: "AIService call succeeded",
                fields: [
                    "method": method,
                    "durationMs": String(durationMs)
                ]
            )
            return result
        } catch let error as LLMClientError {
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            FormaPipelineTracer.logError(
                stage: .aiTask,
                message: "AIService LLM client error",
                fields: [
                    "method": method,
                    "durationMs": String(durationMs),
                    "llmError": String(describing: error)
                ]
            )
            #if DEBUG
            let mapped = AICommandParser.map(error)
            Self.debugLogger.error(
                "Coach AI backend failure [\(method, privacy: .public)]: llm=\(String(describing: error), privacy: .public) mapped=\(String(describing: mapped), privacy: .public)"
            )
            throw mapped
            #else
            throw AICommandParser.map(error)
            #endif
        } catch let error as AIServiceError {
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            FormaPipelineTracer.logError(
                stage: .aiTask,
                message: "AIService validation error",
                fields: [
                    "method": method,
                    "durationMs": String(durationMs),
                    "error": String(describing: error)
                ]
            )
            throw error
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            FormaPipelineTracer.logError(
                stage: .aiTask,
                message: "AIService unexpected error",
                fields: [
                    "method": method,
                    "durationMs": String(durationMs),
                    "error": error.localizedDescription
                ]
            )
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }
}
