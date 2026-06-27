//
//  CoachPendingCopyFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Concise chat copy for pending Coach confirmations.
//

import Foundation

enum CoachPendingCopyFormatter {

    enum NutritionLineStyle {
        case full
        case compact
    }

    enum FoodCopyTone {
        case vague
        case highConfidenceSimple
        case standard
    }

    // MARK: - Food

    static func foodPendingChatMessage(
        draft: FoodDraft,
        confidence: AIConfidence,
        originalText: String
    ) -> String {
        guard draft.hasUsableNutritionEstimate else {
            return "Estimating nutrition for \(naturalFoodName(draft.name))."
        }

        let tone = foodCopyTone(confidence: confidence, draft: draft, originalText: originalText)
        let headline = foodHeadline(draft: draft, tone: tone)
        let nutritionLine = chatNutritionLine(
            for: draft,
            style: tone == .highConfidenceSimple ? .compact : .full
        )
        let footer = foodFooter(tone: tone)

        return [headline, nutritionLine, "", footer].joined(separator: "\n")
    }

    static func foodHeadline(draft: FoodDraft, tone: FoodCopyTone) -> String {
        let name = naturalFoodName(draft.name)
        switch tone {
        case .vague:
            return "Estimated a generic \(name):"
        case .highConfidenceSimple, .standard:
            return "Estimated \(name):"
        }
    }

    static func chatNutritionLine(for draft: FoodDraft, style: NutritionLineStyle) -> String {
        let calories = "\(draft.calories) kcal"
        let protein = "\(formatMacro(draft.protein))g protein"

        switch style {
        case .compact:
            return "\(calories) · \(protein)"
        case .full:
            let carbs = "\(formatMacro(draft.carbs))g carbs"
            let fat = "\(formatMacro(draft.fat))g fat"
            return "\(calories) · \(protein) · \(carbs) · \(fat)"
        }
    }

    static func foodFooter(tone: FoodCopyTone) -> String {
        switch tone {
        case .vague:
            return FormaProductCopy.Coach.foodEditIngredientsFooter
        case .highConfidenceSimple:
            return FormaProductCopy.Coach.foodConfirmBelowFooter
        case .standard:
            return FormaProductCopy.Coach.foodEditPortionFooter
        }
    }

    static func foodCopyTone(
        confidence: AIConfidence,
        draft: FoodDraft,
        originalText: String
    ) -> FoodCopyTone {
        if isVagueFood(confidence: confidence, draft: draft, originalText: originalText) {
            return .vague
        }
        if confidence == .high {
            return .highConfidenceSimple
        }
        return .standard
    }

    // MARK: - Workout

    static func workoutPendingChatMessage(
        draft: WorkoutDraft,
        assistantMessage: String?
    ) -> String {
        var lines = ["Parsed workout:"]
        if let name = draft.name, !name.isEmpty {
            lines.append(name)
        }
        let details = [
            draft.durationMinutes.map { "\($0) min" },
            draft.estimatedCaloriesBurned.map { "\($0) kcal burned" }
        ].compactMap(\.self)
        if !details.isEmpty {
            lines.append(details.joined(separator: " · "))
        }
        if let context = trimmedAssistantContext(assistantMessage) {
            lines.append("")
            lines.append(context)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private static func isVagueFood(
        confidence: AIConfidence,
        draft: FoodDraft,
        originalText: String
    ) -> Bool {
        if confidence == .low { return true }
        let combined = "\(originalText) \(draft.name)".lowercased()
        let vagueMarkers = [
            "mysterious", "generic", "unknown",
            "not sure", "unsure", "leftovers", "something"
        ]
        if vagueMarkers.contains(where: { combined.contains($0) }) {
            return true
        }
        if combined.contains("bowl") && !combined.contains("rice bowl") {
            return true
        }
        return false
    }

    private static func naturalFoodName(_ name: String) -> String {
        var words = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        let leadingFillers = ["a", "an", "the", "my", "generic", "mysterious"]
        while let first = words.first, leadingFillers.contains(first) {
            words.removeFirst()
        }

        guard !words.isEmpty else {
            return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return words.joined(separator: " ")
    }

    private static func trimmedAssistantContext(_ message: String?) -> String? {
        guard let message else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        let boilerplate = [
            "please confirm",
            "confirm or edit",
            "confirm before",
            "use the bar below",
            "here's my estimate"
        ]
        if boilerplate.contains(where: { lowered.contains($0) }) {
            return nil
        }
        return trimmed
    }

    private static func formatMacro(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
