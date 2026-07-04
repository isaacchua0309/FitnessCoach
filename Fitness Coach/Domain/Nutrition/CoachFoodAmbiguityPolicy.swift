//
//  CoachFoodAmbiguityPolicy.swift
//  Fitness Coach
//
//  Forma — Central ambiguity handling for Coach food logging.
//  Avoids falsely precise pending logs for vague or high-risk meals.
//

import Foundation

enum CoachFoodAmbiguityOutcome: Equatable, Sendable {
    /// Continue with the current meal draft and confidence.
    case proceed
    /// Ask one concise question before creating a pending log card.
    case clarifyFirst(String)
    /// Show a pending log with widened range, assumptions, and low confidence.
    case proceedAmbiguous(FoodLogDraft, AIConfidence)
}

struct CoachFoodAmbiguityPostEstimateInput: Equatable, Sendable {
    var prompt: String
    var meal: FoodLogDraft
    var confidence: AIConfidence
    var fromPhotoAnalysis: Bool
    var clarifyingQuestion: String?
    var photoNeedsUserReview: Bool
}

enum CoachFoodAmbiguityPolicy {

    // MARK: - Pre-estimate (before AI / pending card)

    /// Returns a clarification outcome when the prompt cannot be estimated without more context.
    static func preEstimateOutcome(
        prompt: String,
        hasImageAttachment: Bool
    ) -> CoachFoodAmbiguityOutcome? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if hasImageAttachment {
            return nil
        }

        if isBareContextReference(trimmed) {
            return .clarifyFirst(clarificationQuestion(for: .missingReference))
        }

        if isMealSlotOnlyPrompt(trimmed) {
            return .clarifyFirst(clarificationQuestion(for: .missingMealDetails))
        }

        return nil
    }

    // MARK: - Post-estimate (before pending confirmation card)

    static func postEstimateOutcome(
        input: CoachFoodAmbiguityPostEstimateInput
    ) -> CoachFoodAmbiguityOutcome {
        let prompt = input.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var meal = FoodEstimateTrustNormalizer.normalize(input.meal, prompt: prompt)
        let confidence = input.confidence

        if !meal.hasUsableNutritionEstimate {
            return .clarifyFirst(clarificationQuestion(for: .missingMealDetails))
        }

        if input.fromPhotoAnalysis {
            if shouldClarifyForPhotoSignals(input: input, meal: meal) {
                let question = bestClarifyingQuestion(
                    prompt: prompt,
                    meal: meal,
                    clarifyingQuestion: input.clarifyingQuestion,
                    reason: .photoAmbiguity
                )
                return .clarifyFirst(question)
            }
        }

        if hasExplicitPortion(in: prompt) || mealHasExplicitPortion(meal) {
            return .proceed
        }

        if isHighRiskAmbiguousFood(prompt: prompt, meal: meal) {
            if shouldAskInsteadOfPending(meal: meal, confidence: confidence) {
                let question = bestClarifyingQuestion(
                    prompt: prompt,
                    meal: meal,
                    clarifyingQuestion: input.clarifyingQuestion,
                    reason: .highRiskPortion
                )
                return .clarifyFirst(question)
            }
            return .proceedAmbiguous(
                prepareAmbiguousPendingMeal(meal, prompt: prompt),
                .low
            )
        }

        if confidence == .low || meal.requiresClarificationBeforeLogging {
            return .proceedAmbiguous(
                prepareAmbiguousPendingMeal(meal, prompt: prompt),
                .low
            )
        }

        return .proceed
    }

    /// Photo session reducer hook — whether to pause for clarification before pending.
    static func photoSessionShouldClarify(result: ImageAnalysisSessionResult) -> Bool {
        let input = CoachFoodAmbiguityPostEstimateInput(
            prompt: result.summary,
            meal: result.mealDraft,
            confidence: result.confidence,
            fromPhotoAnalysis: true,
            clarifyingQuestion: result.clarifyingQuestion,
            photoNeedsUserReview: result.mealDraft.requiresClarificationBeforeLogging
        )
        if case .clarifyFirst = postEstimateOutcome(input: input) {
            return true
        }
        return false
    }

    // MARK: - Portion detection

    static func hasExplicitPortion(in text: String) -> Bool {
        let lower = text.lowercased()
        if lower.range(
            of: #"\d+(\.\d+)?\s*(g|gram|grams|kg|ml|milliliter|millilitre|oz|lb|cup|cups|tbsp|tablespoon|tablespoons)\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if lower.range(
            of: #"\d+(\.\d+)?\s*(piece|pieces|slice|slices|pc|pcs|egg|eggs|scoop|scoops|serving|servings|count)\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if lower.range(
            of: #"\d+\s*-\s*\d+\s*(g|gram|grams)\b"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        return false
    }

    static func mealHasExplicitPortion(_ meal: FoodLogDraft) -> Bool {
        meal.components.contains { component in
            if let quantity = component.quantity, quantity > 0 {
                return true
            }
            if let source = component.sourceText, hasExplicitPortion(in: source) {
                return true
            }
            return false
        }
    }

    // MARK: - High-risk detection

    static func isHighRiskAmbiguousFood(prompt: String, meal: FoodLogDraft) -> Bool {
        if !FoodCompoundDishDetector.analyze(prompt: prompt).matchedDishes.isEmpty {
            return true
        }
        if highRiskPatterns.contains(where: { matchesPattern($0, in: prompt) }) {
            return true
        }
        let combined = ([meal.displayName] + meal.components.map(\.name)).joined(separator: " ")
        return highRiskPatterns.contains(where: { matchesPattern($0, in: combined) })
    }

    static func likelyHiddenSauceOrOil(prompt: String, meal: FoodLogDraft) -> Bool {
        let texts = [prompt, meal.displayName] + meal.components.map(\.name) + meal.assumptions
        return texts.contains { text in
            text.range(
                of: #"\b(sauce|oil|dressing|mayo|mayonnaise|gravy|butter|sambal|chili|creamy|fried)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    // MARK: - Private

    private enum ClarificationReason {
        case missingReference
        case missingMealDetails
        case highRiskPortion
        case photoAmbiguity
    }

    private static let highRiskPatterns = [
        #"\bchicken rice\b"#,
        #"\bcaifan\b"#,
        #"\bcai fan\b"#,
        #"\bcai png\b"#,
        #"\beconomy rice\b"#,
        #"\bmixed rice\b"#,
        #"\bmala\b"#,
        #"\bmalatang\b"#,
        #"\bbuffet\b"#,
        #"\bcurry rice\b"#,
        #"\byong tau foo\b"#,
        #"\bytf\b"#,
        #"\bnasi lemak\b"#,
        #"\bchar kway teow\b"#,
        #"\bchar kway\b"#,
        #"\blaksa\b"#,
        #"\bsalad with dressing\b"#,
        #"\bsalad.+dressing\b"#,
        #"\bchicken breast\b"#,
        #"\bhawker\b"#,
    ]

    private static let bareContextReferencePattern = try! NSRegularExpression(
        pattern: #"^\s*(log|add|track|record)\s+(this|that|it|my meal|the meal)\s*\.?\s*$"#,
        options: [.caseInsensitive]
    )

    private static let mealSlotOnlyPattern = try! NSRegularExpression(
        pattern: #"^\s*(log|add|track|record)\s+(my\s+)?(breakfast|lunch|dinner|snack|meal)\s*\.?\s*$"#,
        options: [.caseInsensitive]
    )

    private static let photoAmbiguityPattern = try! NSRegularExpression(
        pattern: #"\b(cropped|unclear|blurry|multiple plate|several plate|multiple dishes|hard to tell)\b"#,
        options: [.caseInsensitive]
    )

    private static func isBareContextReference(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return bareContextReferencePattern.firstMatch(in: text, range: range) != nil
    }

    private static func isMealSlotOnlyPrompt(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return mealSlotOnlyPattern.firstMatch(in: text, range: range) != nil
    }

    private static func matchesPattern(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func shouldClarifyForPhotoSignals(
        input: CoachFoodAmbiguityPostEstimateInput,
        meal: FoodLogDraft
    ) -> Bool {
        if input.photoNeedsUserReview,
           let question = input.clarifyingQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !question.isEmpty,
           !hasExplicitPortion(in: input.prompt),
           !mealHasExplicitPortion(meal) {
            return true
        }

        let combined = ([input.prompt, meal.displayName, meal.notes ?? ""] + meal.uncertaintyReasons + meal.assumptions)
            .joined(separator: " ")
        let range = NSRange(combined.startIndex..<combined.endIndex, in: combined)
        if photoAmbiguityPattern.firstMatch(in: combined, range: range) != nil {
            return true
        }

        return false
    }

    private static func shouldAskInsteadOfPending(
        meal: FoodLogDraft,
        confidence: AIConfidence
    ) -> Bool {
        guard confidence == .low else { return false }
        guard meal.components.count <= 1 else { return false }
        let name = meal.components.first?.name ?? meal.displayName
        return isGenericFoodName(name)
    }

    private static func isGenericFoodName(_ name: String) -> Bool {
        name.range(
            of: #"\b(unknown|generic|unidentified|mixed meal|food item|meal item|something|stuff)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func prepareAmbiguousPendingMeal(
        _ meal: FoodLogDraft,
        prompt: String
    ) -> FoodLogDraft {
        var adjusted = meal
        adjusted.confidence = .low

        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: adjusted.totalCalories,
            confidence: .low,
            lower: adjusted.calorieRangeLower,
            upper: adjusted.calorieRangeUpper
        )
        adjusted.calorieRangeLower = resolution.lower
        adjusted.calorieRangeUpper = resolution.upper
        if let warning = resolution.warning {
            adjusted.warnings.append(warning)
        }

        if adjusted.uncertaintyReasons.isEmpty {
            adjusted.uncertaintyReasons.append("Portion size is unclear.")
        }

        if likelyHiddenSauceOrOil(prompt: prompt, meal: adjusted),
           !adjusted.uncertaintyReasons.contains(where: { $0.localizedCaseInsensitiveContains("sauce") || $0.localizedCaseInsensitiveContains("oil") }) {
            adjusted.uncertaintyReasons.append("Hidden sauce or cooking oil amount is uncertain.")
        }

        if adjusted.assumptions.isEmpty {
            adjusted.assumptions.append("Portion and preparation were estimated from limited details.")
        }

        adjusted.requiresClarificationBeforeLogging = true
        adjusted.riskLevel = .high
        adjusted.primaryUncertainty = adjusted.primaryUncertainty ?? adjusted.uncertaintyReasons.first
        return adjusted
    }

    private static func bestClarifyingQuestion(
        prompt: String,
        meal: FoodLogDraft,
        clarifyingQuestion: String?,
        reason: ClarificationReason
    ) -> String {
        if let question = clarifyingQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !question.isEmpty {
            return question
        }
        if let suggested = meal.suggestedClarifications.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggested.isEmpty {
            return suggested
        }

        switch reason {
        case .missingReference:
            return "What should I log? Describe the food or attach a meal photo."
        case .missingMealDetails:
            return "What did you eat? Include the food and portion if you can."
        case .highRiskPortion:
            return portionClarificationQuestion(for: prompt, meal: meal)
        case .photoAmbiguity:
            return "The photo looks unclear. What portion did you have, or which items were on the plate?"
        }
    }

    private static func clarificationQuestion(for reason: ClarificationReason) -> String {
        bestClarifyingQuestion(
            prompt: "",
            meal: FoodLogDraft(displayName: "", components: []),
            clarifyingQuestion: nil,
            reason: reason
        )
    }

    private static func portionClarificationQuestion(for prompt: String, meal: FoodLogDraft) -> String {
        let lowered = prompt.lowercased()
        if lowered.contains("chicken rice") || meal.displayName.lowercased().contains("chicken rice") {
            return "Was this a small, regular, or large chicken rice plate?"
        }
        if lowered.contains("economy rice") || lowered.contains("mixed rice") || lowered.contains("caifan") || lowered.contains("cai fan") {
            return "How many dishes did you add to the rice, and were they mostly veg or meat?"
        }
        if lowered.contains("buffet") {
            return "Roughly how many platefuls or main items did you take from the buffet?"
        }
        if lowered.contains("salad") {
            return "About how much dressing was on the salad — light, regular, or heavy?"
        }
        if lowered.contains("chicken breast") {
            return "How much chicken breast was it — grams or palm-size?"
        }
        return "What portion did you have? A rough size or weight helps."
    }
}
