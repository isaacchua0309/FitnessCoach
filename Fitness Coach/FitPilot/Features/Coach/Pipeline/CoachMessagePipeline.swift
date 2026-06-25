//
//  CoachMessagePipeline.swift
//  Fitness Coach
//
//  FitPilot AI — Cheap-model-first routing for Coach messages.
//

import Foundation

enum NoOpResponse: Equatable, Sendable {
    case casual(String)
    case meaningless(String)
}

enum AITaskType: Equatable, Sendable {
    case answerWithCheapModel
    case answerWithStrongModel
}

struct AITask: Equatable, Sendable {
    var type: AITaskType
    var originalText: String
    var intentResult: CoachIntentResult
}

struct LocalFoodEstimateRequest: Equatable, Sendable {
    var estimate: LocalFoodEstimate
    var originalText: String
    var userAskedToLog: Bool
}

enum CoachMutationRequest: Equatable, Sendable {
    case deleteMeal(MealType)
    case deleteLastFood
    case editLastFoodQuantity(Double, unit: String?)
}

enum CoachRoute: Equatable, Sendable {
    case noOp(NoOpResponse)
    case localCommand(ParsedCommand)
    case localFoodEstimate(LocalFoodEstimateRequest)
    case action(CoachAction, intentResult: CoachIntentResult)
    case localMutation(CoachMutationRequest)
    case ai(AITask)
    case clarification(String)
    case invalid(String)
}

struct CoachRouteDecision: Equatable, Sendable {
    var route: CoachRoute
    var rawMessage: String
    var normalizedMessage: String
    var detectedIntent: CoachIntent
    var confidence: Double
    var chosenHandler: String
    var fallbackReason: String?
}

struct CoachIntentClassifier: Sendable {
    private let aiService: AIServiceProtocol
    private let config: CoachModelConfig

    init(aiService: AIServiceProtocol, config: CoachModelConfig = .default) {
        self.aiService = aiService
        self.config = config
    }

    func classifyWithCheapModel(_ text: String, context: AIContext) async throws -> CoachIntentResult {
        try await aiService.classifyCoachIntent(text, context: context, config: config)
    }
}

struct CoachMessagePipeline: Sendable {
    private let classifier: CoachIntentClassifier
    private let config: CoachModelConfig
    private let localCommandParser: LocalCommandParser
    private let nutritionEstimator: LocalNutritionEstimator

    init(
        aiService: AIServiceProtocol,
        config: CoachModelConfig = .default,
        localCommandParser: LocalCommandParser = .standard,
        nutritionEstimator: LocalNutritionEstimator = .standard
    ) {
        self.classifier = CoachIntentClassifier(aiService: aiService, config: config)
        self.config = config
        self.localCommandParser = localCommandParser
        self.nutritionEstimator = nutritionEstimator
    }

    func process(_ text: String, context: AIContext) async throws -> CoachRouteDecision {
        let input = InputNormalizer.normalize(text)
        let result = try await classifier.classifyWithCheapModel(input.trimmedText, context: context)
        return resolveRoute(for: result, input: input)
    }

    func resolveRoute(for result: CoachIntentResult, input: NormalizedInput) -> CoachRouteDecision {
        if input.isPunctuationOnly || input.meaningfulTokenCount == 0 {
            return decision(
                route: .noOp(.meaningless(CoachResponseBuilder.tryFitnessPrompt)),
                input: input,
                result: result,
                handler: "empty_input"
            )
        }

        switch result.intent {
        case .unrelatedOrUnsupported:
            return decision(
                route: .invalid(CoachResponseBuilder.unknownResponse),
                input: input,
                result: result,
                handler: "fallback",
                fallbackReason: result.reason ?? "Classifier marked the message outside Coach scope."
            )

        case .appHelp:
            return decision(
                route: .noOp(.casual(CoachResponseBuilder.appHelpResponse)),
                input: input,
                result: result,
                handler: "app_help"
            )

        case .dailySummary:
            return decision(
                route: .localCommand(ParsedCommand(intent: .status, originalText: input.trimmedText)),
                input: input,
                result: result,
                handler: "local_status"
            )

        case .logFood, .logWater, .logWeight, .logWorkout, .editLog, .deleteLog:
            return resolveMutationRoute(for: result, input: input)

        case .calorieLookup, .macroLookup, .mealDecision, .nutritionAdvice,
             .workoutAdvice, .weightLossAdvice, .generalConversation:
            let taskType: AITaskType = result.requiresEscalation ? .answerWithStrongModel : .answerWithCheapModel
            if result.requiresEscalation || result.canAnswerWithCheapModel {
                return decision(
                    route: .ai(
                        AITask(
                            type: taskType,
                            originalText: input.trimmedText,
                            intentResult: result
                        )
                    ),
                    input: input,
                    result: result,
                    handler: taskType == .answerWithStrongModel ? "strong_model_answer" : "cheap_model_answer"
                )
            }
            return decision(
                route: .clarification("I need a little more detail to answer that well."),
                input: input,
                result: result,
                handler: "clarification",
                fallbackReason: "Classifier marked answer route as unavailable."
            )
        }
    }

    private func resolveMutationRoute(
        for result: CoachIntentResult,
        input: NormalizedInput
    ) -> CoachRouteDecision {
        if result.intent == .logFood,
           let estimate = nutritionEstimator.estimate(input),
           estimate.confidence == .high {
            return decision(
                route: .localFoodEstimate(
                    LocalFoodEstimateRequest(
                        estimate: estimate,
                        originalText: input.trimmedText,
                        userAskedToLog: true
                    )
                ),
                input: input,
                result: result,
                handler: "local_food_validation"
            )
        }

        if let action = result.action {
            return decision(
                route: .action(action, intentResult: result),
                input: input,
                result: result,
                handler: "classifier_action"
            )
        }

        if let mutation = localMutation(for: input.normalizedText) {
            return decision(
                route: .localMutation(mutation),
                input: input,
                result: result,
                handler: "local_mutation"
            )
        }

        switch result.intent {
        case .logFood:
            if let estimate = nutritionEstimator.estimate(input) {
                return decision(
                    route: .localFoodEstimate(
                        LocalFoodEstimateRequest(
                            estimate: estimate,
                            originalText: input.trimmedText,
                            userAskedToLog: true
                        )
                    ),
                    input: input,
                    result: result,
                    handler: "local_food_validation"
                )
            }
        case .logWater, .logWeight:
            switch localCommandParser.parse(input.trimmedText) {
            case .success(let command):
                return decision(
                    route: .localCommand(command),
                    input: input,
                    result: result,
                    handler: "local_command_validation"
                )
            case .invalid(_, let reason), .ambiguous(_, let reason):
                return decision(
                    route: .invalid(reason),
                    input: input,
                    result: result,
                    handler: "invalid_local_command",
                    fallbackReason: reason
                )
            case .needsAI, .unsupported:
                break
            }
        case .editLog, .deleteLog:
            if let command = undoCommand(from: input.trimmedText) {
                return decision(
                    route: .localCommand(command),
                    input: input,
                    result: result,
                    handler: "local_edit_delete_validation"
                )
            }
        case .logWorkout:
            break
        case .dailySummary, .calorieLookup, .macroLookup, .mealDecision,
             .nutritionAdvice, .workoutAdvice, .weightLossAdvice, .appHelp,
             .generalConversation, .unrelatedOrUnsupported:
            break
        }

        return decision(
            route: .clarification("I can do that, but I need the amount or details before changing your log."),
            input: input,
            result: result,
            handler: "mutation_needs_details",
            fallbackReason: "Classifier required app mutation but did not provide a valid action."
        )
    }

    private func decision(
        route: CoachRoute,
        input: NormalizedInput,
        result: CoachIntentResult,
        handler: String,
        fallbackReason: String? = nil
    ) -> CoachRouteDecision {
        CoachRouteDecision(
            route: route,
            rawMessage: input.trimmedText,
            normalizedMessage: input.normalizedText,
            detectedIntent: result.intent,
            confidence: result.confidence,
            chosenHandler: handler,
            fallbackReason: fallbackReason
        )
    }

    private func localMutation(for text: String) -> CoachMutationRequest? {
        if text.contains("delete lunch") || text.contains("remove lunch") {
            return .deleteMeal(.lunch)
        }
        if text.contains("delete breakfast") || text.contains("remove breakfast") {
            return .deleteMeal(.breakfast)
        }
        if text.contains("delete dinner") || text.contains("remove dinner") {
            return .deleteMeal(.dinner)
        }
        if text.contains("delete snack") || text.contains("remove snack") {
            return .deleteMeal(.snack)
        }
        if text.contains("delete last food") || text.contains("delete last meal") || text.contains("undo last meal") {
            return .deleteLastFood
        }
        if (text.contains("edit last meal") || text.contains("change last meal")),
           let quantity = gramQuantity(in: text) {
            return .editLastFoodQuantity(quantity, unit: "g")
        }
        return nil
    }

    private func undoCommand(from text: String) -> ParsedCommand? {
        switch localCommandParser.parse(text) {
        case .success(let command):
            return command
        case .invalid, .ambiguous, .needsAI, .unsupported:
            return nil
        }
    }

    private func gramQuantity(in text: String) -> Double? {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*(?:g|gram|grams)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let valueRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[valueRange])
    }
}
