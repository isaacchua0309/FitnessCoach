//
//  CoachRouteDecider.swift
//  Fitness Coach
//
//  FitPilot AI — async orchestrator: local guard → cheap LLM classify → route.
//

import Foundation

enum NoOpResponse: Equatable, Sendable {
    case casual(String)
    case meaningless(String)
}

enum CoachAITask: Equatable, Sendable {
    case estimateFood(String)
    case mealAdvice(String)
    case parseWorkout(String)
    case editEntry(String)
    case deleteEntry(String)
    case multiAction(String)
    case photoFoodAnalysis(imageData: Data?, prompt: String)
    case parseCommand(String)
}

struct LocalFoodEstimateRequest: Equatable, Sendable {
    var estimate: LocalFoodEstimate
    var originalText: String
    var userAskedToLog: Bool
}

enum CoachRoute: Equatable, Sendable {
    case noOp(NoOpResponse)
    case localCommand(ParsedCommand)
    case localFoodEstimate(LocalFoodEstimateRequest)
    case classifiedFood(FoodDraft, originalText: String, intentResult: CoachIntentResult)
    case ai(RoutedAITask)
    case trainingLogRedirect
    case clarification(String)
    case invalid(String)
}

struct CoachRouteDecision: Equatable, Sendable {
    var route: CoachRoute
    var rawMessage: String
    var normalizedMessage: String
    var routeSource: CoachRouteSource
    var intent: CoachIntent?
    var modelTier: CoachModelTier?
    var chosenHandler: String
    var reason: String?
    var requiresAPI: Bool
}

final class CoachRouteDecider: Sendable {
    private let localGuard: LocalNoAPIGuard
    private let intentRouter: CoachIntentRouter
    private var recentClassifyCache: [String: Date] = [:]
    private let classifyDedupWindow: TimeInterval = 8

    nonisolated init(
        localGuard: LocalNoAPIGuard? = nil,
        intentRouter: CoachIntentRouter? = nil
    ) {
        self.localGuard = localGuard ?? LocalNoAPIGuard()
        self.intentRouter = intentRouter ?? CoachIntentRouter()
    }

    func decide(
        text: String,
        context: AIContext,
        aiService: AIServiceProtocol,
        config: CoachModelConfig? = nil
    ) async throws -> CoachRouteDecision {
        let resolvedConfig = config ?? .default
        let input = InputNormalizer.normalize(text)
        let guardRoute = localGuard.evaluate(input)

        switch guardRoute {
        case .noOp(let response):
            return localDecision(
                route: .noOp(response),
                input: input,
                handler: "no_op",
                reason: "Empty or meaningless input."
            )

        case .greeting(let message):
            return localDecision(
                route: .noOp(.casual(message)),
                input: input,
                handler: "greeting",
                reason: "Standalone greeting."
            )

        case .deterministicCommand(let command):
            return localDecision(
                route: .localCommand(command),
                input: input,
                handler: "local_command",
                reason: "Deterministic local parser match."
            )

        case .localFoodEstimate(let request):
            return localDecision(
                route: .localFoodEstimate(request),
                input: input,
                handler: "local_food_estimate",
                reason: "High-confidence local food catalog match."
            )

        case .clarification(let message):
            return localDecision(
                route: .clarification(message),
                input: input,
                handler: "local_clarification",
                reason: "Local parser needs clarification."
            )

        case .passToCheapLLM:
            FitPilotPipelineTracer.event(
                stage: .localGuard,
                level: .info,
                message: "Continuing to cheap LLM classifier"
            )
            break
        }

        let classifyKey = classifyCacheKey(text: input.normalizedText, context: context)
        if isDuplicateClassify(key: classifyKey) {
            FitPilotPipelineTracer.event(
                stage: .classifyDedup,
                level: .warn,
                message: "Duplicate classify suppressed",
                fields: ["cacheKey": classifyKey]
            )
            return localDecision(
                route: .clarification("I am still working on your last request. Give me a moment."),
                input: input,
                handler: "classify_dedup",
                reason: "Duplicate classify within dedup window."
            )
        }
        recordClassify(key: classifyKey)

        let classifyStarted = Date()
        let classifier = CheapLLMIntentClassifier(aiService: aiService)
        let intentResult: CoachIntentResult
        do {
            intentResult = try await classifier.classify(
                text: input.originalText,
                context: context,
                config: resolvedConfig
            )
        } catch {
            let durationMs = Int(Date().timeIntervalSince(classifyStarted) * 1_000)
            FitPilotPipelineTracer.logError(
                stage: .classify,
                message: "Intent classification failed",
                fields: [
                    "durationMs": String(durationMs),
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]
            )
            throw error
        }

        let classifyDurationMs = Int(Date().timeIntervalSince(classifyStarted) * 1_000)
        FitPilotPipelineTracer.event(
            stage: .classify,
            level: .info,
            message: "Intent classification succeeded",
            fields: [
                "durationMs": String(classifyDurationMs),
                "intent": intentResult.intent.rawValue,
                "requiresEscalation": String(intentResult.requiresEscalation),
                "canAnswerWithCheapModel": String(intentResult.canAnswerWithCheapModel)
            ]
        )

        CoachRouteDebugLogger.logMessage(
            "classify intent=\(intentResult.intent.rawValue) escalation=\(intentResult.requiresEscalation)"
        )

        let route = intentRouter.route(intentResult: intentResult, originalText: input.originalText)
        let requiresAPI = routeRequiresAPI(route)
        let tier = routedTier(from: route)

        return CoachRouteDecision(
            route: route,
            rawMessage: input.originalText,
            normalizedMessage: input.normalizedText,
            routeSource: .cheapClassifier,
            intent: intentResult.intent,
            modelTier: tier,
            chosenHandler: handler(for: route, intent: intentResult.intent),
            reason: intentResult.reason,
            requiresAPI: requiresAPI
        )
    }

    // MARK: - Local decisions

    private func localDecision(
        route: CoachRoute,
        input: NormalizedCoachInput,
        handler: String,
        reason: String
    ) -> CoachRouteDecision {
        CoachRouteDecision(
            route: route,
            rawMessage: input.originalText,
            normalizedMessage: input.normalizedText,
            routeSource: .localGuard,
            intent: nil,
            modelTier: nil,
            chosenHandler: handler,
            reason: reason,
            requiresAPI: false
        )
    }

    // MARK: - Classify dedup

    private func classifyCacheKey(text: String, context: AIContext) -> String {
        let fingerprint = "\(context.todaySummary?.caloriesRemaining ?? -1)-\(context.todaySummary?.proteinRemaining ?? -1)"
        return "\(text.lowercased())|\(fingerprint)"
    }

    private func isDuplicateClassify(key: String) -> Bool {
        guard let last = recentClassifyCache[key] else { return false }
        return Date().timeIntervalSince(last) < classifyDedupWindow
    }

    private func recordClassify(key: String) {
        recentClassifyCache[key] = Date()
        if recentClassifyCache.count > 32 {
            recentClassifyCache = recentClassifyCache.filter {
                Date().timeIntervalSince($0.value) < classifyDedupWindow
            }
        }
    }

    // MARK: - Route metadata

    private func routeRequiresAPI(_ route: CoachRoute) -> Bool {
        switch route {
        case .ai: return true
        case .classifiedFood: return true
        case .noOp, .localCommand, .localFoodEstimate, .clarification, .invalid, .trainingLogRedirect:
            return false
        }
    }

    private func routedTier(from route: CoachRoute) -> CoachModelTier? {
        if case .ai(let task) = route { return task.tier }
        if case .classifiedFood = route { return .cheap }
        return nil
    }

    private func handler(for route: CoachRoute, intent: CoachIntent) -> String {
        switch route {
        case .ai(let task):
            switch task.task {
            case .estimateFood: return "ai_estimate_food"
            case .mealAdvice: return task.tier == .strong ? "strong_meal_advice" : "cheap_meal_advice"
            case .parseWorkout: return "ai_parse_workout"
            case .editEntry: return "ai_edit_entry"
            case .deleteEntry: return "ai_delete_entry"
            case .multiAction: return "ai_multi_action"
            case .photoFoodAnalysis: return "ai_photo_food"
            case .parseCommand: return "ai_parse_command"
            }
        case .classifiedFood:
            return "classified_food"
        case .localCommand:
            return "local_command"
        case .localFoodEstimate:
            return "local_food_estimate"
        case .noOp:
            return intent == .appHelp ? "app_help" : "no_op"
        case .clarification:
            return "clarification"
        case .invalid:
            return "unsupported"
        case .trainingLogRedirect:
            return "training_log_redirect"
        }
    }
}
