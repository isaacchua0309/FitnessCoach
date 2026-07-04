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

    static func food(
        _ entry: FoodEntry,
        log: DailyLog?,
        fromPhotoAnalysis: Bool = false
    ) -> String {
        let leadIn = fromPhotoAnalysis
            ? "Logged \(entry.name) from your meal photo."
            : "Logged \(entry.name)."
        var response = leadIn
        response += """


        \(entry.calories) kcal · \(FoodEntryFormFormatter.formatMacro(entry.protein))g protein · \(FoodEntryFormFormatter.formatMacro(entry.carbs))g carbs · \(FoodEntryFormFormatter.formatMacro(entry.fat))g fat
        """
        if let log {
            response += CoachNutritionSummaryFormatter.foodLoggedSuffix(
                nutrition: nutritionSummary(from: log)
            )
        }
        response += """


        \(FormaProductCopy.Coach.foodLoggedTimelineNote)
        """
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
        mealDraft: FoodLogDraft,
        confidence: AIConfidence,
        originalText: String,
        sanityWarning: String? = nil,
        fromPhotoAnalysis: Bool = false
    ) -> String {
        CoachPendingCopyFormatter.foodPendingChatMessage(
            mealDraft: mealDraft,
            confidence: confidence,
            originalText: originalText,
            sanityWarning: sanityWarning,
            fromPhotoAnalysis: fromPhotoAnalysis
        )
    }

    static func aiFoodEstimatePending(
        draft: FoodDraft,
        confidence: AIConfidence,
        originalText: String,
        fromPhotoAnalysis: Bool = false
    ) -> String {
        aiFoodEstimatePending(
            mealDraft: FoodLogDraftMapper.fromLegacyDraft(draft),
            confidence: confidence,
            originalText: originalText,
            fromPhotoAnalysis: fromPhotoAnalysis
        )
    }

    static func mealPhotoClarification(_ question: String) -> String {
        ImageAnalysisSessionCopy.clarificationPrompt(question)
    }

    static func mealPhotoError(_ error: CoachMealPhotoError) -> String {
        switch error {
        case .userCancelled:
            return ""
        case .noImage, .loadFailed, .encodingFailed:
            return FormaProductCopy.Coach.mealPhotoPreparationFailed
        case .cameraUnavailable:
            return "This device can't take photos for Coach. Choose an image from your library or log the meal manually."
        case .cameraPermissionDenied:
            return "Camera access is turned off for Forma. Enable it in Settings to take meal photos, or choose from your library."
        }
    }

    static func speechError(_ error: CoachSpeechError) -> String {
        switch error {
        case .microphonePermissionDenied:
            return "Microphone access is turned off for Forma. Enable it in Settings to dictate messages to Coach."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition is turned off for Forma. Enable it in Settings to dictate messages to Coach."
        case .recognizerUnavailable:
            return "Voice input isn't available on this device right now. Type your message instead."
        case .audioSessionFailed:
            return "Coach couldn't start listening. Try again or type your message instead."
        case .recognitionFailed:
            return "Coach couldn't understand that. Try again or type your message instead."
        }
    }

    static func mealPhotoAnalysisFailed(_ error: AIServiceError) -> String {
        switch error {
        case .authenticationFailed:
            return "I couldn't analyze that photo because your session expired. \(AIServiceError.coachSessionFailureMessage) You can try again or log manually."
        case .networkUnavailable:
            return "I couldn't reach Coach to analyze that photo. Check your connection, then try again or log manually."
        case .payloadTooLarge, .imageEncodingFailed:
            return FormaProductCopy.Coach.mealPhotoPreparationFailed
        case .backendRejectedImage:
            return "Coach couldn't use that photo for analysis. Try another image or log the meal manually."
        case .requestTimedOut:
            return "I couldn't analyze that photo in time. \(error.userMessage) You can try again or log manually."
        case .modelUnavailable, .backendUnavailable:
            return "Coach couldn't analyze that photo right now. \(error.userMessage) You can try again or log manually."
        case .invalidNutritionJSON, .parsingFailed:
            return "I couldn't read a reliable nutrition estimate from that photo. Try another shot or log manually."
        case .validationFailed, .invalidResponse, .decodingFailed:
            return "I couldn't read a reliable nutrition estimate from that photo. Try another shot or log manually."
        case .requestFailed, .featureDisabled:
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

    static func status(
        _ log: DailyLog,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        contextHints: CoachResponseContextHints? = nil,
        training: DailyTrainingActivity? = nil
    ) -> String {
        let snapshot = CoachDailyStatusSnapshot.from(
            log: log,
            hints: contextHints,
            healthIntelligence: healthIntelligence,
            training: training
        )
        return CoachDailyStatusBuilder.message(from: snapshot)
    }

    static func status(from snapshot: CoachDailyStatusSnapshot) -> String {
        CoachDailyStatusBuilder.message(from: snapshot)
    }

    // MARK: Daily Review

    static func dailyReview(
        _ review: DailyReview,
        contextHints: CoachResponseContextHints? = nil
    ) -> String {
        var message = DailyReviewFormatter.coachMessage(from: review)
        if let timelineSupplement = CoachAIResponseContextAdapter.statusTimelineSupplement(
            from: contextHints?.timelineEvents ?? []
        ) {
            message += "\n\n\(timelineSupplement)"
        }
        return CoachAIResponseContextAdapter.appendMissingDataDisclaimer(
            to: message,
            hints: contextHints,
            includeSteps: true,
            includeWorkouts: true
        )
    }

    // MARK: Meal Advice

    static func mealAdvice(
        log: DailyLog?,
        profile: UserProfile?,
        hasWorkoutToday: Bool,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        intent: CoachIntent? = nil,
        assistantMessage: String?,
        contextHints: CoachResponseContextHints? = nil
    ) -> String {
        if intent == .workoutAdvice {
            return workoutAdviceResponse(
                hasWorkoutToday: hasWorkoutToday,
                healthIntelligence: healthIntelligence,
                assistantMessage: assistantMessage,
                contextHints: contextHints
            )
        }

        let message: String
        if let assistantMessage,
           !assistantMessage.isEmpty,
           !isGenericPlaceholder(assistantMessage) {
            message = composeMealAdviceResponse(
                assistantMessage: assistantMessage,
                log: log,
                hasWorkoutToday: hasWorkoutToday,
                healthIntelligence: healthIntelligence
            )
        } else if let log {
            let nutrition = nutritionSummary(from: log)
            let brief = DailyBriefBuilder.todayBrief(
                nutrition: nutrition,
                hasWorkoutToday: hasWorkoutToday,
                trainingFrequency: profile?.trainingFrequencyPerWeek ?? 0,
                healthIntelligence: healthIntelligence
            )

            var lines = CoachNutritionSummaryFormatter.mealAdviceLines(
                nutrition: nutrition,
                brief: brief,
                healthIntelligence: healthIntelligence
            )

            if let opening = CoachHealthGuidanceFormatter.mealAdviceOpening(from: healthIntelligence) {
                lines.insert(opening, at: 0)
            }

            let supplements = CoachHealthGuidanceFormatter.mealAdviceSupplementLines(from: healthIntelligence)
            lines.append(contentsOf: supplements.filter { line in
                !lines.joined(separator: " ").lowercased().contains(line.lowercased())
            })

            message = lines.joined(separator: " ")
        } else {
            message = "Tell me what you've eaten so far and I'll suggest your next move."
        }

        return CoachAIResponseContextAdapter.appendMissingDataDisclaimer(
            to: message,
            hints: contextHints,
            includeSteps: true,
            includeWorkouts: true
        )
    }

    static func workoutAdviceResponse(
        hasWorkoutToday: Bool,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        assistantMessage: String?,
        contextHints: CoachResponseContextHints? = nil
    ) -> String {
        let localAdvice = CoachHealthGuidanceFormatter.workoutAdvice(
            from: healthIntelligence,
            hasWorkoutToday: hasWorkoutToday
        )

        let composed: String
        if let assistantMessage,
           !assistantMessage.isEmpty,
           !isGenericPlaceholder(assistantMessage) {
            let sanitized = CoachHealthGuidanceFormatter.removeRedundantWorkoutQuestions(
                from: assistantMessage,
                knowsWorkoutStatus: CoachHealthGuidanceFormatter.knowsWorkoutStatus(from: healthIntelligence)
                    || hasWorkoutToday
            )

            if sanitized.lowercased().contains("recovery")
                || sanitized.lowercased().contains("train")
                || sanitized.lowercased().contains("workout") {
                composed = CoachHealthGuidanceFormatter.appendUniqueLines(
                    to: sanitized,
                    lines: [localAdvice]
                )
            } else {
                composed = "\(sanitized) \(localAdvice)"
            }
        } else {
            composed = localAdvice
        }

        return CoachAIResponseContextAdapter.appendMissingDataDisclaimer(
            to: composed,
            hints: contextHints,
            includeSteps: false,
            includeWorkouts: true
        )
    }

    private static func composeMealAdviceResponse(
        assistantMessage: String,
        log: DailyLog?,
        hasWorkoutToday: Bool,
        healthIntelligence: CoachHealthIntelligenceContext?
    ) -> String {
        let knowsWorkout = CoachHealthGuidanceFormatter.knowsWorkoutStatus(from: healthIntelligence)
            || hasWorkoutToday

        var message = CoachHealthGuidanceFormatter.removeRedundantWorkoutQuestions(
            from: assistantMessage,
            knowsWorkoutStatus: knowsWorkout
        )

        if let opening = CoachHealthGuidanceFormatter.mealAdviceOpening(from: healthIntelligence),
           !message.lowercased().contains(opening.lowercased()) {
            message = "\(opening) \(message)"
        }

        message = CoachHealthGuidanceFormatter.appendUniqueLines(
            to: message,
            lines: CoachHealthGuidanceFormatter.mealAdviceSupplementLines(from: healthIntelligence)
        )

        if let log {
            let nutrition = nutritionSummary(from: log)
            if nutrition.remaining.protein > 30,
               !message.lowercased().contains("protein") {
                message += " You still need about \(FoodEntryFormFormatter.formatMacro(nutrition.remaining.protein))g protein today."
            }
        }

        return message.trimmingCharacters(in: .whitespacesAndNewlines)
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
        "I can help with food, water, weight, workouts, and fitness guidance. What would you like to track or ask?"

    static let unsupportedScopeResponse = unknownResponse

    static let inputTooLongResponse =
        "That message is too long for Coach. Please shorten it and try again."

    static let lowConfidenceClarification =
        "I'm not fully sure what you want me to log. Could you rephrase it with the amount and item?"

    static let classifierUnavailableResponse =
        "I'm having trouble understanding right now. Could you rephrase what you'd like to log or ask?"

    static let backendUnavailableResponse = FormaProductCopy.Error.coachUnavailable

    // MARK: Entry reference resolution

    static let entryReferenceUnsupportedAction =
        "I can only edit or delete existing food entries with this flow."

    static let entryReferencePendingNotLogged =
        "That meal is not logged yet. Confirm or cancel the pending estimate first."

    static let entryReferenceRejectedOrPending =
        "That estimate was rejected or is still pending. I cannot change it as a logged entry."

    static let entryReferenceDeletedOrMissing =
        "I could not find that food entry for today."

    static let entryReferenceAssistantOnly =
        "I need a meal name or meal type — not just my previous reply."

    static func entryReferenceClarification(candidateLabels: [String] = []) -> String {
        guard !candidateLabels.isEmpty else {
            return "I'm not sure which entry you mean. Try naming the meal or saying something like \"delete lunch\"."
        }
        let joined = candidateLabels.joined(separator: "; ")
        return "I found multiple matches (\(joined)). Which one should I change?"
    }

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
