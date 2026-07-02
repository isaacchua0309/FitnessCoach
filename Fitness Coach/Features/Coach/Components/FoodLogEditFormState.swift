//
//  FoodLogEditFormState.swift
//  Fitness Coach
//
//  FitPilot AI — Edit form state for multi-component Coach food estimates.
//

import Foundation

struct FoodComponentFormState: Equatable, Identifiable {
    var id: UUID
    var name: String
    var quantityText: String
    var unit: String
    var preparationState: String
    var caloriesText: String
    var proteinText: String
    var carbsText: String
    var fatText: String
    var sourceText: String

    init(component: FoodComponent) {
        id = component.id
        name = component.name
        quantityText = FoodEntryFormFormatter.formatOptionalDouble(component.quantity) ?? ""
        unit = component.unit ?? ""
        preparationState = component.preparationState ?? ""
        caloriesText = "\(component.calories)"
        proteinText = FoodEntryFormFormatter.formatMacro(component.protein)
        carbsText = FoodEntryFormFormatter.formatMacro(component.carbs)
        fatText = FoodEntryFormFormatter.formatMacro(component.fat)
        sourceText = component.sourceText ?? ""
    }

    func makeComponent(confidence: ConfidenceLevel) throws -> FoodComponent {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw FoodEntryFormError.missingName }

        return FoodComponent(
            id: id,
            name: trimmedName,
            quantity: try parseOptionalPositiveDouble(quantityText),
            unit: optionalTrimmedString(unit),
            preparationState: optionalTrimmedString(preparationState),
            calories: try parseNonNegativeInt(caloriesText),
            protein: try parseMacro(proteinText, error: .invalidProtein),
            carbs: try parseMacro(carbsText, error: .invalidCarbs),
            fat: try parseMacro(fatText, error: .invalidFat),
            confidence: confidence,
            sourceText: optionalTrimmedString(sourceText)
        )
    }

    private func optionalTrimmedString(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseNonNegativeInt(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else {
            throw FoodEntryFormError.invalidCalories
        }
        return value
    }

    private func parseMacro(_ text: String, error: FoodEntryFormError) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let value = Double(trimmed), value >= 0 else { throw error }
        return value
    }

    private func parseOptionalPositiveDouble(_ text: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0 else {
            throw FoodEntryFormError.invalidQuantity
        }
        return value
    }
}

struct FoodLogEditFormState: Equatable {
    var mealType: MealType?
    var displayName: String
    var componentStates: [FoodComponentFormState]

    init(mealDraft: FoodLogDraft) {
        mealType = mealDraft.mealType
        displayName = mealDraft.displayName
        componentStates = mealDraft.components.map(FoodComponentFormState.init(component:))
    }

    init(foodDraft: FoodDraft) {
        self.init(mealDraft: FoodLogDraftMapper.fromLegacyDraft(foodDraft))
    }

    var isMultiComponent: Bool {
        componentStates.count > 1
    }

    var totalCalories: Int {
        componentStates.compactMap { Int($0.caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .reduce(0, +)
    }

    func makeMealDraft(original: FoodLogDraft) throws -> FoodLogDraft {
        let rebuilt = try rebuildMeal(original: original)
        if isEquivalent(rebuilt, to: original) {
            return rebuilt
        }
        var corrected = rebuilt
        corrected.source = .corrected
        return corrected
    }

    private func rebuildMeal(original: FoodLogDraft) throws -> FoodLogDraft {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw FoodEntryFormError.missingName }
        guard !componentStates.isEmpty else { throw FoodEntryFormError.missingName }

        let components = try componentStates.map {
            try $0.makeComponent(confidence: original.confidence)
        }

        var meal = FoodLogDraft(
            id: original.id,
            displayName: trimmedName,
            mealType: mealType,
            components: components,
            confidence: original.confidence,
            source: original.source,
            notes: original.notes,
            warnings: original.warnings,
            imageUrl: original.imageUrl
        )
        return FoodLogDraftMapper.reconcileTotals(meal)
    }

    private func isEquivalent(_ rebuilt: FoodLogDraft, to original: FoodLogDraft) -> Bool {
        rebuilt.displayName == original.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            && rebuilt.mealType == original.mealType
            && rebuilt.components == original.components
            && rebuilt.notes == original.notes
    }
}
