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
        guard let log else {
            return "Logged \(loggedMl)ml water."
        }
        return CoachNutritionSummaryFormatter.waterLoggedMessage(
            loggedMl: loggedMl,
            nutrition: nutritionSummary(from: log)
        )
    }

    // MARK: Weight

    static func weight(_ weightKg: Double) -> String {
        "Logged your weight as \(FoodEntryFormFormatter.formatWeight(weightKg)) kg."
    }

    // MARK: Food

    static func food(_ entry: FoodEntry, log: DailyLog?) -> String {
        var response = "Logged \(entry.name)."
        response += """


        \(entry.calories) kcal · \(FoodEntryFormFormatter.formatMacro(entry.protein))g protein
        """
        if let log {
            response += CoachNutritionSummaryFormatter.foodLoggedSuffix(
                nutrition: nutritionSummary(from: log)
            )
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

    static func mealPhotoError(_ error: CoachMealPhotoError) -> String {
        switch error {
        case .userCancelled:
            return ""
        case .noImage:
            return "I couldn't read that photo. Try another image or log the meal manually."
        case .loadFailed:
            return "That photo couldn't be prepared for analysis. Try again or use manual entry."
        case .cameraUnavailable:
            return "Camera isn't available on this device. Choose a photo from your library instead."
        }
    }

    static func mealPhotoAnalysisFailed(_ error: AIServiceError) -> String {
        switch error {
        case .authenticationFailed:
            return AIServiceError.coachSessionFailureMessage
        case .requestTimedOut:
            return "I couldn't analyze that photo in time. \(error.userMessage) You can try again or log manually."
        default:
            return "I couldn't analyze that photo right now. \(error.userMessage) You can try again or log manually."
        }
    }

    static func waterPending(_ draft: WaterDraft, assistantMessage: String?) -> String {
        "Log \(draft.amountMl)ml water?"
    }

    static func weightPending(_ draft: WeightDraft, assistantMessage: String?) -> String {
        "Log \(FoodEntryFormFormatter.formatWeight(draft.weightKg)) kg?"
    }

    static func mutationPending(assistantMessage: String?) -> String {
        guard let message = assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty
        else {
            return "Review this change before applying it."
        }
        return message
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
        CoachNutritionSummaryFormatter.statusMessage(from: nutritionSummary(from: log))
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
            nutrition: nutrition,
            hasWorkoutToday: hasWorkoutToday,
            trainingFrequency: profile?.trainingFrequencyPerWeek ?? 0
        )

        return CoachNutritionSummaryFormatter.mealAdviceLines(
            nutrition: nutrition,
            brief: brief
        ).joined(separator: " ")
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
            Tomorrow looks like a training day. Hit \(nutrition.targets.calories) kcal with at least \(FoodEntryFormFormatter.formatMacro(nutrition.targets.protein))g protein, \
            front-load water before noon, and log your morning weight if you haven't yet.
            """
        }

        if nutrition.remaining.protein > 40 {
            return """
            Close today with protein first — you still need about \(FoodEntryFormFormatter.formatMacro(nutrition.remaining.protein))g. \
            Tomorrow, weigh in, log breakfast early, and keep calories near \(nutrition.targets.calories) kcal.
            """
        }

        return """
        You're in a good rhythm today. Tomorrow: log breakfast, hit \(FoodEntryFormFormatter.formatMacro(nutrition.targets.protein))g protein, \
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

    private static func formatWater(_ ml: Int) -> String {
        PlanDisplayFormatter.formatGroupedInteger(ml)
    }
}
