//
//  CoachRouteDecider.swift
//  Fitness Coach
//
//  FitPilot AI — routes user text before any API or mutation occurs.
//

import Foundation

enum NoOpResponse: Equatable, Sendable {
    case casual(String)
    case meaningless(String)
}

enum AITaskType: Equatable, Sendable {
    case parseCommand
    case estimateFood
    case generateMealAdvice
    case parseWorkout
    case editEntry
    case deleteEntry
    case multiAction
}

struct AITask: Equatable, Sendable {
    var type: AITaskType
    var originalText: String
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
    case localCoaching(CoachingRequest)
    case localMutation(CoachMutationRequest)
    case ai(AITask)
    case clarification(String)
    case invalid(String)
}

struct CoachRouteDecider {

    private let localCommandParser: LocalCommandParser
    private let nutritionEstimator: LocalNutritionEstimator
    private let coachingHeuristics: LocalCoachingHeuristics

    init(
        localCommandParser: LocalCommandParser = .standard,
        nutritionEstimator: LocalNutritionEstimator = .standard,
        coachingHeuristics: LocalCoachingHeuristics = LocalCoachingHeuristics()
    ) {
        self.localCommandParser = localCommandParser
        self.nutritionEstimator = nutritionEstimator
        self.coachingHeuristics = coachingHeuristics
    }

    func decide(_ text: String) -> CoachRoute {
        let input = InputNormalizer.normalize(text)
        let normalized = input.normalizedText

        if let noOp = noOpResponse(for: input) {
            return .noOp(noOp)
        }

        if let mutation = localMutation(for: input) {
            return .localMutation(mutation)
        }

        switch localCommandParser.parse(input.trimmedText) {
        case .success(let command):
            return .localCommand(command)
        case .invalid(_, let reason):
            return .invalid(reason)
        case .ambiguous(_, let reason):
            return .clarification(reason)
        case .needsAI, .unsupported:
            break
        }

        if let estimate = nutritionEstimator.estimate(input), hasFoodLoggingVerb(normalized) {
            return .localFoodEstimate(
                LocalFoodEstimateRequest(
                    estimate: estimate,
                    originalText: input.trimmedText,
                    userAskedToLog: hasFoodLoggingVerb(normalized)
                )
            )
        }

        if let coachingRequest = coachingHeuristics.request(for: input) {
            return .localCoaching(coachingRequest)
        }

        if isMultiAction(normalized) {
            return .ai(AITask(type: .multiAction, originalText: input.trimmedText))
        }

        if isWorkoutLike(normalized) {
            return .ai(AITask(type: .parseWorkout, originalText: input.trimmedText))
        }

        if isMealAdviceQuestion(normalized) {
            return .ai(AITask(type: .generateMealAdvice, originalText: input.trimmedText))
        }

        if isFoodLike(normalized) {
            return .ai(AITask(type: .estimateFood, originalText: input.trimmedText))
        }

        if isEditOrDeleteLike(normalized) {
            return .ai(AITask(type: normalized.contains("delete") || normalized.contains("remove") ? .deleteEntry : .editEntry, originalText: input.trimmedText))
        }

        return .invalid(CoachResponseBuilder.unknownResponse)
    }

    private func noOpResponse(for input: NormalizedInput) -> NoOpResponse? {
        let text = input.normalizedText
        let casualResponses: [String: String] = [
            "hi": "Hey. Tell me what you ate, drank, weighed, trained, or ask what to do next.",
            "hello": "Hey. Tell me what you ate, drank, weighed, trained, or ask what to do next.",
            "hey": "Hey. Tell me what you ate, drank, weighed, trained, or ask what to do next.",
            "thanks": "Anytime.",
            "thank you": "Anytime.",
            "ok": "Got it.",
            "okay": "Got it.",
            "nice": "Nice."
        ]

        if let response = casualResponses[text] {
            return .casual(response)
        }

        if text.hasPrefix("good morning") {
            return .casual("Good morning. Want to log weight, breakfast, water, or check today's plan?")
        }

        if input.isPunctuationOnly || input.meaningfulTokenCount == 0 {
            return .meaningless(CoachResponseBuilder.tryFitnessPrompt)
        }

        if input.meaningfulTokenCount == 1, !singleTokenHasFitnessMeaning(text) {
            return .meaningless(CoachResponseBuilder.tryFitnessPrompt)
        }

        return nil
    }

    private func localMutation(for input: NormalizedInput) -> CoachMutationRequest? {
        let text = input.normalizedText

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

        if (text.contains("edit last meal") || text.contains("change last meal") || text.contains("change lunch") || text.contains("edit lunch")),
           let quantity = gramQuantity(in: text) {
            return .editLastFoodQuantity(quantity, unit: "g")
        }

        return nil
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

    private func hasFoodLoggingVerb(_ text: String) -> Bool {
        text.hasPrefix("log ")
            || text.hasPrefix("add ")
            || text.hasPrefix("track ")
            || text.hasPrefix("ate ")
            || text.hasPrefix("had ")
            || text.hasPrefix("i ate ")
            || text.hasPrefix("i had ")
    }

    private func singleTokenHasFitnessMeaning(_ text: String) -> Bool {
        [
            "status", "water", "weight", "weigh", "calories", "protein",
            "breakfast", "lunch", "dinner", "snack", "review", "chicken",
            "rice", "kebab", "salad", "dessert", "whey", "egg", "eggs",
            "pasta", "salmon", "tuna", "milk", "banana", "apple", "orange",
            "watermelon", "potato", "bench", "deadlift", "squat", "run", "yoga",
            "badminton"
        ].contains(text)
    }

    private func isMealAdviceQuestion(_ text: String) -> Bool {
        (text.contains("should i eat") || text.contains("can i eat") || text.contains("can i fit") || text.contains("how much should i eat"))
            && text.contains("eat")
    }

    private func isWorkoutLike(_ text: String) -> Bool {
        let workoutWords = [
            "bench", "deadlift", "squat", "press", "row", "curl", "run", "ran",
            "km", "yoga", "badminton", "workout", "trained", "training", "sets"
        ]
        let hasWorkoutWord = workoutWords.contains { CommandParserUtilities.containsWord($0, in: text) }
        let hasSetPattern = text.range(of: #"[0-9]+\s*x\s*[0-9]+"#, options: .regularExpression) != nil
        return hasWorkoutWord || hasSetPattern
    }

    private func isFoodLike(_ text: String) -> Bool {
        let foodWords = [
            "ate", "had", "food", "meal", "chicken", "rice", "kebab", "salad",
            "dessert", "lunch", "dinner", "breakfast", "snack", "whey", "egg",
            "pasta", "salmon", "tuna"
        ]
        return hasFoodLoggingVerb(text) || foodWords.contains { CommandParserUtilities.containsWord($0, in: text) }
    }

    private func isEditOrDeleteLike(_ text: String) -> Bool {
        text.contains("delete")
            || text.contains("remove")
            || text.contains("edit")
            || text.contains("change")
    }

    private func isMultiAction(_ text: String) -> Bool {
        let hasFood = isFoodLike(text)
        let hasWater = CommandParserUtilities.containsWord("water", in: text)
        return hasFood && hasWater && (text.contains(" and ") || text.contains(","))
    }
}
