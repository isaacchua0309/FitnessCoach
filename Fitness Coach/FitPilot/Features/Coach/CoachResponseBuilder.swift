//
//  CoachResponseBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds deterministic, user-facing assistant strings.
//
//  This builder only formats display text from domain models. It does not call
//  services, access SwiftData, call AI, or own calculations beyond simple
//  display formatting (it may use MacroCalculator for remaining values).
//

import Foundation

enum CoachResponseBuilder {

    static let automaticDayMessage =
        "Your day updates automatically at midnight. Each calendar day gets its own log."

    // MARK: Water

    static func water(loggedMl: Int, log: DailyLog?) -> String {
        var response = "Logged \(loggedMl)ml water."
        if let log {
            let remaining = max(log.targets.waterTargetMl - log.waterConsumedMl, 0)
            response += """

            Water today:
            \(formatWater(log.waterConsumedMl)) / \(formatWater(log.targets.waterTargetMl))ml
            \(formatWater(remaining))ml remaining.
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
            let targets = MacroCalculator.macroTargets(from: log.targets)
            let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)
            let proteinRemaining = max(remaining.protein, 0)
            response += """


            Today:
            \(log.totals.calories) / \(targets.calories) kcal
            \(formatMacro(proteinRemaining))g protein remaining.
            """
        }
        return response
    }

    static func localFoodEstimatePending(_ estimate: LocalFoodEstimate) -> String {
        let draft = estimate.draft
        return """
        I estimated this as:

        \(draft.name)
        \(draft.calories) kcal · \(formatMacro(draft.protein))g protein

        Confirm before I log it?
        """
    }

    static func aiFoodEstimatePending(
        draft: FoodDraft,
        assistantMessage: String?
    ) -> String {
        var lines: [String] = []
        if let assistantMessage, !assistantMessage.isEmpty {
            lines.append(assistantMessage)
            lines.append("")
        }
        lines.append("I estimate this as:")
        lines.append("")
        lines.append(draft.name)
        lines.append("\(draft.calories) kcal · \(formatMacro(draft.protein))g protein")
        lines.append("")
        lines.append("Confirm before I log it?")
        return lines.joined(separator: "\n")
    }

    static func workoutPending(_ draft: WorkoutDraft, assistantMessage: String?) -> String {
        var lines: [String] = []
        if let assistantMessage, !assistantMessage.isEmpty {
            lines.append(assistantMessage)
            lines.append("")
        }
        lines.append("I parsed this workout:")
        if let name = draft.name {
            lines.append(name)
        }
        let details = [
            draft.durationMinutes.map { "\($0) min" },
            draft.estimatedCaloriesBurned.map { "\($0) kcal burned" }
        ].compactMap(\.self)
        if !details.isEmpty {
            lines.append(details.joined(separator: " · "))
        }
        lines.append("")
        lines.append("Reply \"confirm\" to log it, or \"cancel\" to discard.")
        return lines.joined(separator: "\n")
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
        let targets = MacroCalculator.macroTargets(from: log.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)
        let remainingCalories = max(remaining.calories, 0)

        return """
        Today so far:
        Calories: \(log.totals.calories) / \(targets.calories) kcal
        Protein: \(formatMacro(log.totals.protein)) / \(formatMacro(targets.protein))g
        Carbs: \(formatMacro(log.totals.carbs)) / \(formatMacro(targets.carbs))g
        Fat: \(formatMacro(log.totals.fat)) / \(formatMacro(targets.fat))g
        Water: \(log.waterConsumedMl) / \(log.targets.waterTargetMl)ml

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

        let targets = MacroCalculator.macroTargets(from: log.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)
        let waterRemaining = WaterTargetCalculator.remainingMl(
            consumedMl: log.waterConsumedMl,
            targetMl: log.targets.waterTargetMl
        )

        let brief = DailyBriefBuilder.todayBrief(
            profile: profile,
            caloriesRemaining: remaining.calories,
            proteinRemaining: remaining.protein,
            waterRemainingMl: waterRemaining,
            hasWorkoutToday: hasWorkoutToday,
            trainingFrequency: profile?.trainingFrequencyPerWeek ?? 0
        )

        var lines: [String] = [brief.recommendation]

        if remaining.protein > 30 {
            lines.append("You still need about \(formatMacro(remaining.protein))g protein today.")
        } else {
            lines.append("Protein is on track at \(formatMacro(log.totals.protein))g of \(formatMacro(targets.protein))g.")
        }

        if remaining.calories > 0 {
            lines.append("\(remaining.calories) kcal left — use them for nutrient-dense food, not empty snacks.")
        } else if remaining.calories < 0 {
            lines.append("You're \(abs(remaining.calories)) kcal over target. Keep the next meal lean and portion-controlled.")
        }

        if waterRemaining > 400 {
            lines.append("Drink \(formatWater(waterRemaining))ml more water to stay on pace.")
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

        let targets = MacroCalculator.macroTargets(from: log.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)
        let trainingDays = profile.trainingFrequencyPerWeek
        let isTrainingTomorrow = !hasWorkoutToday && trainingDays >= 3

        if isTrainingTomorrow {
            return """
            Tomorrow looks like a training day. Hit \(targets.calories) kcal with at least \(formatMacro(targets.protein))g protein, \
            front-load water before noon, and log your morning weight if you haven't yet.
            """
        }

        if remaining.protein > 40 {
            return """
            Close today with protein first — you still need about \(formatMacro(remaining.protein))g. \
            Tomorrow, weigh in, log breakfast early, and keep calories near \(targets.calories) kcal.
            """
        }

        return """
        You're in a good rhythm today. Tomorrow: log breakfast, hit \(formatMacro(targets.protein))g protein, \
        and keep water above \(formatWater(log.targets.waterTargetMl))ml.
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

    static let aiFoodSaveFailed =
        "I could not save that food entry. Please check the values and try again."

    static let greetingResponse =
        "Tell me what you ate, drank, weighed, or trained — or ask what to focus on next."

    static let tryFitnessPrompt =
        "Tell me what you ate, drank, weighed, trained, or ask what to do next."

    static let unknownResponse =
        "I can help with food, water, weight, workouts, or meal decisions. Try: 'log 500g chicken breast'."

    static let backendUnavailableResponse =
        "Coach is briefly unavailable — try a direct command like 'log 500ml water'."

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
