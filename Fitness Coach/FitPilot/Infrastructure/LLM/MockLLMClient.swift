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

    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        let text = request.text.lowercased()
        let result: CoachIntentResult

        if text.contains("calories do i have left")
            || text.contains("calories left")
            || text.contains("calories remaining")
            || text == "status" {
            result = CoachIntentResult(
                intent: .dailySummary,
                confidence: 0.96,
                domain: .app,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                reason: "User is asking for deterministic daily targets."
            )
        } else if let action = mockWaterAction(text: text) {
            result = CoachIntentResult(
                intent: .logWater,
                confidence: 0.96,
                domain: .hydration,
                requiresAppMutation: true,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                action: action,
                reason: "User wants to log water."
            )
        } else if let action = mockWeightAction(text: text) {
            result = CoachIntentResult(
                intent: .logWeight,
                confidence: 0.96,
                domain: .bodyMetrics,
                requiresAppMutation: true,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                action: action,
                reason: "User wants to log weight."
            )
        } else if let action = mockWorkoutAction(text: text) {
            result = CoachIntentResult(
                intent: .logWorkout,
                confidence: 0.9,
                domain: .fitness,
                requiresAppMutation: true,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                action: action,
                reason: "User wants to log a workout."
            )
        } else if let action = mockFoodAction(text: text) {
            result = CoachIntentResult(
                intent: .logFood,
                confidence: 0.91,
                domain: .nutrition,
                requiresAppMutation: true,
                requiresUserContext: true,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                action: action,
                reason: "User wants to log food."
            )
        } else if text.contains("how many calories") || text.contains("calories in") || text.contains("calories is") {
            result = CoachIntentResult(
                intent: .calorieLookup,
                confidence: 0.94,
                domain: .nutrition,
                requiresAppMutation: false,
                requiresUserContext: false,
                canAnswerWithCheapModel: true,
                requiresEscalation: false,
                entities: CoachIntentEntities(food: extractFoodPhrase(from: text))
            )
        } else if text.contains("macro") || text.contains("protein") || text.contains("carb") || text.contains("fat") {
            result = CoachIntentResult(
                intent: .nutritionAdvice,
                confidence: 0.9,
                domain: .nutrition,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false,
                entities: CoachIntentEntities(food: extractFoodPhrase(from: text))
            )
        } else if text.contains("should i eat") || text.contains("what should i eat") || text.contains("eat for dinner") {
            result = CoachIntentResult(
                intent: .mealDecision,
                confidence: 0.92,
                domain: .nutrition,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false,
                entities: CoachIntentEntities(food: extractFoodPhrase(from: text), meal: text.contains("dinner") ? "dinner" : nil)
            )
        } else if text.contains("12 week")
                    || text.contains("plan")
                    || text.contains("fat loss")
                    || text.contains("strength training and diet") {
            result = CoachIntentResult(
                intent: .weightLossAdvice,
                confidence: 0.9,
                domain: .fitness,
                requiresAppMutation: false,
                requiresUserContext: true,
                canAnswerWithCheapModel: false,
                requiresEscalation: true,
                reason: "Long-range plan requires deeper personalization."
            )
        } else if text == "hello" || text == "hi" || text == "hey" || text == "help" {
            result = CoachIntentResult(
                intent: .appHelp,
                confidence: 0.86,
                domain: .app,
                requiresAppMutation: false,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false
            )
        } else {
            result = CoachIntentResult(
                intent: .unrelatedOrUnsupported,
                confidence: 0.8,
                domain: .unrelated,
                requiresAppMutation: false,
                requiresUserContext: false,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                reason: "No fitness or nutrition task detected."
            )
        }

        return AICoachIntentClassificationResponse(intentResult: result)
    }

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

        if text.contains("bench") || text.contains("deadlift") || text.contains("5x5") {
            let benchSets = (1...5).map {
                ExerciseSetDraft(exerciseName: "Bench press", setNumber: $0, reps: 5, weightKg: 90, rpe: nil)
            }
            let draft = WorkoutDraft(
                name: "Strength training",
                durationMinutes: 45,
                estimatedCaloriesBurned: 280,
                intensity: .high,
                recoveryDemand: .high,
                notes: "Parsed from Coach text.",
                exerciseSets: benchSets
            )
            let action = AICommandAction(type: .logWorkout, workoutDraft: draft)
            let command = AIParsedCommand(
                originalText: request.text,
                intent: .logWorkout,
                actions: [action],
                confidence: .medium,
                requiresConfirmation: true,
                assistantMessage: "I parsed this as a strength workout. Please confirm before logging.",
                reasoningSummary: "Strength set notation detected."
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
        let text = request.question.lowercased()
        let message: String

        if request.modelTier == .strong || request.intentResult?.requiresEscalation == true {
            message = """
            Here is a practical starting plan: lift 3–4 days per week, keep a modest calorie deficit, hit protein daily, and use weekly weigh-in trends to adjust. Start with repeatable meals and progress training gradually instead of making the first week extreme.
            """
        } else if text.contains("burger") {
            message = """
            Yes, you can fit a burger, but make the rest of the meal intentional. A single restaurant cheeseburger is often around 500–650 kcal; doubles can land closer to 750–900 kcal, and fries or sugary drinks can push the meal past 1,000 kcal. If calories are tight, have the burger, skip fries/drink, and keep the next meal lean. If protein is low, pair it with a lighter high-protein option.
            """
        } else if text.contains("protein") || text.contains("whey") || text.contains("scoop") {
            message = """
            Probably not three full scoops unless your protein is very low today. Most whey is roughly 120 kcal and 24g protein per scoop, so three scoops is about 360 kcal and 72g protein. For most people, 1–2 scoops is enough at once; choose 1 scoop if calories are tight, or 2 scoops if you are meaningfully short on protein.
            """
        } else if text.contains("how many calories") || text.contains("calories in") || text.contains("calories is") {
            message = """
            I can estimate it, but restaurant and packaged foods vary by portion and toppings. Give me the item and size if you have it; otherwise assume a broad range and use the higher end when you are cutting.
            """
        } else {
            message = "Here is the practical move: choose the option that keeps you near today's calorie target while closing your protein gap. If calories are low, go lean and high-protein; if you have room, a moderate portion is fine."
        }

        let response = AICoachResponse(
            message: message,
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

    private func mockWaterAction(text: String) -> CoachAction? {
        guard text.contains("water") || text.contains("ml") else { return nil }
        guard let amount = firstInt(in: text) else { return nil }
        return .logWater(WaterDraft(amountMl: amount))
    }

    private func mockWeightAction(text: String) -> CoachAction? {
        guard text.hasPrefix("weight ") || text.hasPrefix("log weight ") || text.hasPrefix("weigh ") else {
            return nil
        }
        guard let weight = firstDouble(in: text) else { return nil }
        return .logWeight(WeightDraft(weightKg: weight))
    }

    private func mockWorkoutAction(text: String) -> CoachAction? {
        guard text.hasPrefix("ran ") || text.contains("workout") || text.contains("bench") else {
            return nil
        }
        let duration = firstInt(in: text)
        let draft = WorkoutDraft(
            name: text.hasPrefix("ran ") ? "Run" : "Workout",
            durationMinutes: duration,
            estimatedCaloriesBurned: nil,
            intensity: nil,
            recoveryDemand: nil,
            notes: "Parsed by Coach classifier.",
            exerciseSets: []
        )
        return .logWorkout(draft)
    }

    private func mockFoodAction(text: String) -> CoachAction? {
        guard text.hasPrefix("log ") || text.hasPrefix("add ") || text.hasPrefix("ate ") || text.hasPrefix("had ") else {
            return nil
        }
        guard text.contains("chicken") || text.contains("rice") || text.contains("whey") || text.contains("protein") else {
            return nil
        }

        let quantity = firstDouble(in: text)
        let name: String
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double

        if text.contains("chicken") {
            name = "Chicken breast"
            calories = Int(((quantity ?? 500) / 100 * 165).rounded())
            protein = ((quantity ?? 500) / 100 * 31).rounded()
            carbs = 0
            fat = ((quantity ?? 500) / 100 * 3.6).rounded()
        } else if text.contains("whey") || text.contains("protein") {
            name = "Whey protein"
            let scoops = quantity ?? 1
            calories = Int((scoops * 120).rounded())
            protein = scoops * 24
            carbs = scoops * 3
            fat = scoops * 1.5
        } else {
            name = "Chicken rice"
            calories = 650
            protein = 35
            carbs = 75
            fat = 20
        }

        let draft = FoodDraft(
            mealType: nil,
            name: name,
            quantity: quantity,
            unit: text.contains("g") ? "g" : nil,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: "Estimated by Coach classifier."
        )
        return .logFood(draft)
    }

    private func extractFoodPhrase(from text: String) -> String? {
        let removable = [
            "how many calories is", "how many calories in", "calories in",
            "should i eat", "should i have", "for dinner", "for lunch",
            "for breakfast", "?"
        ]
        var phrase = text
        for token in removable {
            phrase = phrase.replacingOccurrences(of: token, with: "")
        }
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func firstInt(in text: String) -> Int? {
        firstDouble(in: text).map { Int($0.rounded()) }
    }

    private func firstDouble(in text: String) -> Double? {
        let pattern = #"[0-9]+(?:\.[0-9]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let valueRange = Range(match.range, in: text)
        else { return nil }
        return Double(text[valueRange])
    }
}
