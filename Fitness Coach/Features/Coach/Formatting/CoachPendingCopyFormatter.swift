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
        mealDraft: FoodLogDraft,
        confidence: AIConfidence,
        originalText: String,
        sanityWarning: String? = nil
    ) -> String {
        guard mealDraft.hasUsableNutritionEstimate else {
            return "Estimating nutrition for \(naturalFoodName(mealDraft.displayName))."
        }

        let tone = foodCopyTone(confidence: confidence, mealDraft: mealDraft, originalText: originalText)
        let headline = foodHeadline(mealDraft: mealDraft, tone: tone)
        let nutritionLine = chatNutritionLine(
            for: mealDraft,
            style: tone == .highConfidenceSimple ? .compact : .full
        )
        let componentLines = componentSummaryLines(for: mealDraft)
        let footer = foodFooter(tone: tone, sanityWarning: sanityWarning)

        var sections = [headline, nutritionLine]
        if !componentLines.isEmpty {
            sections.append("")
            sections.append(contentsOf: componentLines)
        }
        if let sanityWarning, !sanityWarning.isEmpty {
            sections.append("")
            sections.append(sanityWarning)
        }
        sections.append("")
        sections.append(footer)
        return sections.joined(separator: "\n")
    }

    static func foodPendingChatMessage(
        draft: FoodDraft,
        confidence: AIConfidence,
        originalText: String
    ) -> String {
        foodPendingChatMessage(
            mealDraft: FoodLogDraftMapper.fromLegacyDraft(draft),
            confidence: confidence,
            originalText: originalText
        )
    }

    static func foodHeadline(mealDraft: FoodLogDraft, tone: FoodCopyTone) -> String {
        let name = naturalFoodName(mealDraft.displayName)
        switch tone {
        case .vague:
            return "Estimated a generic \(name):"
        case .highConfidenceSimple, .standard:
            return "Estimated \(name):"
        }
    }

    static func foodHeadline(draft: FoodDraft, tone: FoodCopyTone) -> String {
        foodHeadline(mealDraft: FoodLogDraftMapper.fromLegacyDraft(draft), tone: tone)
    }

    static func chatNutritionLine(for mealDraft: FoodLogDraft, style: NutritionLineStyle) -> String {
        let calories = "\(mealDraft.totalCalories) kcal"
        let protein = "\(FoodEntryFormFormatter.formatMacro(mealDraft.totalProtein))g protein"

        switch style {
        case .compact:
            return "\(calories) · \(protein)"
        case .full:
            let carbs = "\(FoodEntryFormFormatter.formatMacro(mealDraft.totalCarbs))g carbs"
            let fat = "\(FoodEntryFormFormatter.formatMacro(mealDraft.totalFat))g fat"
            return "\(calories) · \(protein) · \(carbs) · \(fat)"
        }
    }

    static func chatNutritionLine(for draft: FoodDraft, style: NutritionLineStyle) -> String {
        chatNutritionLine(for: FoodLogDraftMapper.fromLegacyDraft(draft), style: style)
    }

    static func foodFooter(tone: FoodCopyTone, sanityWarning: String? = nil) -> String {
        if sanityWarning != nil {
            return FormaProductCopy.Coach.foodEditPortionFooter
        }
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
        mealDraft: FoodLogDraft,
        originalText: String
    ) -> FoodCopyTone {
        if isVagueFood(confidence: confidence, mealDraft: mealDraft, originalText: originalText) {
            return .vague
        }
        if confidence == .high {
            return .highConfidenceSimple
        }
        return .standard
    }

    static func foodCopyTone(
        confidence: AIConfidence,
        draft: FoodDraft,
        originalText: String
    ) -> FoodCopyTone {
        foodCopyTone(
            confidence: confidence,
            mealDraft: FoodLogDraftMapper.fromLegacyDraft(draft),
            originalText: originalText
        )
    }

    // MARK: - Private

    private static func isVagueFood(
        confidence: AIConfidence,
        mealDraft: FoodLogDraft,
        originalText: String
    ) -> Bool {
        if confidence == .low { return true }
        let combined = "\(originalText) \(mealDraft.displayName)".lowercased()
        let vagueMarkers = [
            "mysterious", "generic", "unknown",
            "not sure", "unsure", "leftovers", "something"
        ]
        if vagueMarkers.contains(where: { combined.contains($0) }) {
            return true
        }
        if combined.contains("bowl") && mealDraft.components.count <= 1 && !combined.contains("rice bowl") {
            return true
        }
        return false
    }

    private static func componentSummaryLines(for mealDraft: FoodLogDraft) -> [String] {
        guard mealDraft.isMultiComponent else { return [] }
        return mealDraft.components.map(FoodComponentDisplayFormatter.summaryLine)
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
}
