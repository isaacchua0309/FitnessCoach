//
//  CoachResponseBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds deterministic, user-facing assistant strings.
//
//  This builder only formats display text from domain models. It does not call
//  services, access SwiftData, call AI, or own calculations beyond simple
//  display formatting. Nutrition values come from DailyNutritionSummaryBuilder.
//

import Foundation

enum CoachResponseBuilder {

    static let automaticDayMessage =
        "Your day updates automatically at midnight. Each calendar day gets its own log."

    private static func nutritionSummary(from log: DailyLog) -> DailyNutritionSummary {
        DailyNutritionSummaryBuilder.build(from: log)
    }

    // MARK: Water

    static func water(loggedMl: Int, log: DailyLog?) -> String {
        var response = "Logged \(loggedMl)ml water."
        if let log {
            let water = nutritionSummary(from: log).water
            response += """

            Water today:
            \(formatWater(water.consumedMl)) / \(formatWater(water.targetMl))ml
            \(formatWater(water.remainingMl))ml remaining.
            """
        }
        return response
    }

    // MARK: Weight

    static func weight(_ weightKg: Double) -> String {
        "Logged your weight as \(formatWeight(weightKg)) kg."
    }

    // MARK: Food

    static func food(_ entry: FoodEntry, log: DailyLog?) -> String {
        var response = "Logged \(entry.name)."
        response += """


        \(entry.calories) kcal · \(formatMacro(entry.protein))g protein
        """
        if let log {
            let nutrition = nutritionSummary(from: log)
            let proteinRemaining = max(nutrition.remaining.protein, 0)
            response += """


            Today:
            \(nutrition.totals.calories) / \(nutrition.targets.calories) kcal
            \(formatMacro(proteinRemaining))g protein remaining.
            """
        }
        return response
    }

    static func localFoodEstimatePending(
        _ estimate: LocalFoodEstimate,
        originalText: String
    ) -> String {
        let confidence: AIConfidence = estimate.confidence == .high ? .high : .medium
        return CoachPendingCopyFormatter.foodPendingChatMessage(
            draft: estimate.draft,
            confidence: confidence,
            originalText: originalText
        )
    }

    static func aiFoodEstimatePending(
        draft: FoodDraft,
        confidence: AIConfidence,
        originalText: String
    ) -> String {
        CoachPendingCopyFormatter.foodPendingChatMessage(
            draft: draft,
            confidence: confidence,
            originalText: originalText
        )
    }

    static func workoutPending(_ draft: WorkoutDraft, assistantMessage: String?) -> String {
        CoachPendingCopyFormatter.workoutPendingChatMessage(
            draft: draft,
            assistantMessage: assistantMessage
        )
    }

    static func waterPending(_ draft: WaterDraft, assistantMessage: String?) -> String {
        "Log \(draft.amountMl)ml water?"
    }

    static func weightPending(_ draft: WeightDraft, assistantMessage: String?) -> String {
        "Log \(formatWeight(draft.weightKg)) kg?"
    }

    static func mutationPending(assistantMessage: String?) -> String {
        guard let message = assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty
        else {
            return "Review this change before applying it."
        }
        return message
    }

    static func workout(_ entry: WorkoutEntry) -> String {
        var lines = ["Logged workout."]

        if let name = entry.name {
            lines.append(name)
        }

        let details = [
            entry.durationMinutes.map { "\($0) min" },
            entry.estimatedCaloriesBurned.map { "\($0) kcal burned" },
            entry.recoveryDemand.map { "\($0.rawValue.capitalized) recovery demand" }
        ].compactMap(\.self)

        if !details.isEmpty {
            lines.append(details.joined(separator: " · "))
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: Undo

    static func undoFood(_ entry: FoodEntry?) -> String {
        guard let entry else {
            return "There was no food entry to undo."
        }
        return "Undid your last food entry: \(entry.name)."
    }

    static func undoWater(_ entry: WaterEntry?) -> String {
        guard let entry else {
            return "There was no water entry to undo."
        }
        return "Undid your last water entry of \(entry.amountMl)ml."
    }

    static func deleteFood(_ entry: FoodEntry) -> String {
        "Deleted \(entry.name)."
    }

    static func editFood(_ entry: FoodEntry) -> String {
        "Updated \(entry.name)."
    }

    // MARK: Status

    static func status(_ log: DailyLog) -> String {
        let nutrition = nutritionSummary(from: log)
        let remainingCalories = max(nutrition.remaining.calories, 0)

        return """
        Today so far:
        Calories: \(nutrition.totals.calories) / \(nutrition.targets.calories) kcal
        Protein: \(formatMacro(nutrition.totals.protein)) / \(formatMacro(nutrition.targets.protein))g
        Carbs: \(formatMacro(nutrition.totals.carbs)) / \(formatMacro(nutrition.targets.carbs))g
        Fat: \(formatMacro(nutrition.totals.fat)) / \(formatMacro(nutrition.targets.fat))g
        Water: \(nutrition.water.consumedMl) / \(nutrition.water.targetMl)ml

        You still have \(remainingCalories) kcal remaining.
        """
    }

    // MARK: Daily Review

    static func dailyReview(_ review: DailyReview) -> String {
        DailyReviewFormatter.coachMessage(from: review)
    }

    // MARK: Meal Advice

    static func mealAdvice(
        log: DailyLog?,
        profile: UserProfile?,
        hasWorkoutToday: Bool,
        assistantMessage: String?
    ) -> String {
        if let assistantMessage,
           !assistantMessage.isEmpty,
           !isGenericPlaceholder(assistantMessage) {
            return assistantMessage
        }

        guard let log else {
            return "Tell me what you've eaten so far and I'll suggest your next move."
        }

        let nutrition = nutritionSummary(from: log)

        let brief = DailyBriefBuilder.todayBrief(
            profile: profile,
            nutrition: nutrition,
            hasWorkoutToday: hasWorkoutToday,
            trainingFrequency: profile?.trainingFrequencyPerWeek ?? 0
        )

        var lines: [String] = [brief.recommendation]

        if nutrition.remaining.protein > 30 {
            lines.append("You still need about \(formatMacro(nutrition.remaining.protein))g protein today.")
        } else {
            lines.append(
                "Protein is on track at \(formatMacro(nutrition.totals.protein))g of \(formatMacro(nutrition.targets.protein))g."
            )
        }

        if nutrition.remaining.calories > 0 {
            lines.append("\(nutrition.remaining.calories) kcal left — use them for nutrient-dense food, not empty snacks.")
        } else if nutrition.remaining.calories < 0 {
            lines.append(
                "You're \(abs(nutrition.remaining.calories)) kcal over target. Keep the next meal lean and portion-controlled."
            )
        }

        if nutrition.water.remainingMl > 400 {
            lines.append("Drink \(formatWater(nutrition.water.remainingMl))ml more water to stay on pace.")
        }

        return lines.joined(separator: " ")
    }

    static func tomorrowFocus(
        log: DailyLog?,
        profile: UserProfile?,
        hasWorkoutToday: Bool
    ) -> String {
        guard let log, let profile else {
            return "Set up your plan first, then I can help you prioritize tomorrow."
        }

        let nutrition = nutritionSummary(from: log)
        let trainingDays = profile.trainingFrequencyPerWeek
        let isTrainingTomorrow = !hasWorkoutToday && trainingDays >= 3

        if isTrainingTomorrow {
            return """
            Tomorrow looks like a training day. Hit \(nutrition.targets.calories) kcal with at least \(formatMacro(nutrition.targets.protein))g protein, \
            front-load water before noon, and log your morning weight if you haven't yet.
            """
        }

        if nutrition.remaining.protein > 40 {
            return """
            Close today with protein first — you still need about \(formatMacro(nutrition.remaining.protein))g. \
            Tomorrow, weigh in, log breakfast early, and keep calories near \(nutrition.targets.calories) kcal.
            """
        }

        return """
        You're in a good rhythm today. Tomorrow: log breakfast, hit \(formatMacro(nutrition.targets.protein))g protein, \
        and keep water above \(formatWater(nutrition.water.targetMl))ml.
        """
    }

    private static func isGenericPlaceholder(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("quick guidance")
            || lowered.contains("here is some")
            || lowered == "here is some quick guidance based on your day."
    }

    // MARK: Placeholders

    static let stepsPlaceholder =
        "Step logging is recognized, but saving steps will be added in a later step."

    static let undoLastPlaceholder =
        "Undo last action is not fully supported yet. Try \"undo food\" or \"undo water\"."

    static let needsAIResponse = FormaProductCopy.Error.coachUnavailable

    static let unsupportedResponse =
        "I can help with logging, calories, macros, meal choices, workouts, water, weight, and your daily targets."

    static let aiNotUnderstood = FormaProductCopy.Error.coachNotUnderstood

    static let aiFoodPendingConfirmation =
        "I estimated this food, but I need your confirmation before logging it."

    static let aiFoodRejected =
        "No problem — I did not log that food."

    static let pendingRejected =
        "No problem — I did not log it."

    static let aiFoodSaveFailed =
        "I could not save that food entry. Please check the values and try again."

    static let greetingResponse =
        "Tell me what you ate, drank, weighed, or trained — or ask what to focus on next."

    static let tryFitnessPrompt =
        "Tell me what you ate, drank, weighed, trained, or ask what to do next."

    static let unknownResponse =
        "I can help with food, water, weight, workouts, or meal decisions. Try: 'log 500g chicken breast'."

    static let backendUnavailableResponse = FormaProductCopy.Error.coachUnavailable

    static let appHelpResponse =
        "Ask me about meals, calories, macros, protein, workouts, water, weight, or today's targets. You can also say things like \"log 500g chicken breast\" or \"add 600ml water\"."

    static func aiFoodPendingMessage(assistantMessage: String?) -> String {
        guard let assistantMessage, !assistantMessage.isEmpty else {
            return aiFoodPendingConfirmation
        }
        return "\(assistantMessage)\n\nConfirm before I log it?"
    }

    // MARK: Formatting Helpers

    private static func formatWeight(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func formatMacro(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private static func formatWater(_ ml: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: ml)) ?? "\(ml)"
    }
}
