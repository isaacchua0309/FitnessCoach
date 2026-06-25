//
//  FoodEntryFormState.swift
//  Fitness Coach
//
//  FitPilot AI — Local form state for manual food entry.
//
//  UI input state only. Conversion produces drafts/updates for FoodLogService.
//

import Foundation

struct FoodEntryFormState: Equatable {
    var mealType: MealType?
    var name: String
    var quantityText: String
    var unit: String
    var caloriesText: String
    var proteinText: String
    var carbsText: String
    var fatText: String
    var fiberText: String
    var sodiumText: String
    var notes: String

    init() {
        mealType = nil
        name = ""
        quantityText = ""
        unit = ""
        caloriesText = ""
        proteinText = ""
        carbsText = ""
        fatText = ""
        fiberText = ""
        sodiumText = ""
        notes = ""
    }

    init(foodEntry: FoodEntry) {
        mealType = foodEntry.mealType
        name = foodEntry.name
        quantityText = FoodEntryFormFormatter.formatOptionalDouble(foodEntry.quantity)
        unit = foodEntry.unit ?? ""
        caloriesText = "\(foodEntry.calories)"
        proteinText = FoodEntryFormFormatter.formatMacro(foodEntry.protein)
        carbsText = FoodEntryFormFormatter.formatMacro(foodEntry.carbs)
        fatText = FoodEntryFormFormatter.formatMacro(foodEntry.fat)
        fiberText = FoodEntryFormFormatter.formatOptionalDouble(foodEntry.fiber)
        sodiumText = FoodEntryFormFormatter.formatOptionalDouble(foodEntry.sodium)
        notes = foodEntry.notes ?? ""
    }

    init(foodDraft: FoodDraft) {
        mealType = foodDraft.mealType
        name = foodDraft.name
        quantityText = FoodEntryFormFormatter.formatOptionalDouble(foodDraft.quantity)
        unit = foodDraft.unit ?? ""
        caloriesText = "\(foodDraft.calories)"
        proteinText = FoodEntryFormFormatter.formatMacro(foodDraft.protein)
        carbsText = FoodEntryFormFormatter.formatMacro(foodDraft.carbs)
        fatText = FoodEntryFormFormatter.formatMacro(foodDraft.fat)
        fiberText = FoodEntryFormFormatter.formatOptionalDouble(foodDraft.fiber)
        sodiumText = FoodEntryFormFormatter.formatOptionalDouble(foodDraft.sodium)
        notes = foodDraft.notes ?? ""
    }

    func makeFoodDraft() throws -> FoodDraft {
        try makeValidatedFoodDraft(source: .manual, confidence: .high)
    }

    func makeAIFoodDraft(original: FoodDraft) throws -> FoodDraft {
        let draft = try makeValidatedFoodDraft(source: original.source, confidence: original.confidence)
        if isEquivalent(to: original) {
            return draft
        }
        var corrected = draft
        corrected.source = .corrected
        return corrected
    }

    private func makeValidatedFoodDraft(
        source: FoodEntrySource,
        confidence: ConfidenceLevel
    ) throws -> FoodDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw FoodEntryFormError.missingName }

        return FoodDraft(
            mealType: mealType,
            name: trimmedName,
            quantity: try parseOptionalPositiveDouble(quantityText),
            unit: optionalTrimmedString(unit),
            calories: try parseNonNegativeInt(caloriesText),
            protein: try parseNonNegativeDouble(proteinText, error: .invalidProtein),
            carbs: try parseNonNegativeDouble(carbsText, error: .invalidCarbs),
            fat: try parseNonNegativeDouble(fatText, error: .invalidFat),
            fiber: try parseOptionalNonNegativeDouble(fiberText, error: .invalidFiber),
            sodium: try parseOptionalNonNegativeDouble(sodiumText, error: .invalidSodium),
            source: source,
            confidence: confidence,
            imageUrl: nil,
            notes: optionalTrimmedString(notes)
        )
    }

    private func isEquivalent(to original: FoodDraft) -> Bool {
        let draft = try? makeValidatedFoodDraft(source: original.source, confidence: original.confidence)
        guard let draft else { return false }
        return draft.mealType == original.mealType
            && draft.name == original.name.trimmingCharacters(in: .whitespacesAndNewlines)
            && draft.quantity == original.quantity
            && draft.unit == original.unit
            && draft.calories == original.calories
            && draft.protein == original.protein
            && draft.carbs == original.carbs
            && draft.fat == original.fat
            && draft.fiber == original.fiber
            && draft.sodium == original.sodium
            && draft.notes == original.notes
    }

    func makeFoodEntryUpdate() throws -> FoodEntryUpdate {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw FoodEntryFormError.missingName }

        return FoodEntryUpdate(
            mealType: mealType,
            name: trimmedName,
            quantity: try parseOptionalPositiveDouble(quantityText),
            unit: optionalTrimmedString(unit),
            calories: try parseNonNegativeInt(caloriesText),
            protein: try parseNonNegativeDouble(proteinText, error: .invalidProtein),
            carbs: try parseNonNegativeDouble(carbsText, error: .invalidCarbs),
            fat: try parseNonNegativeDouble(fatText, error: .invalidFat),
            fiber: try parseOptionalNonNegativeDouble(fiberText, error: .invalidFiber),
            sodium: try parseOptionalNonNegativeDouble(sodiumText, error: .invalidSodium),
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: optionalTrimmedString(notes)
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

    private func parseNonNegativeDouble(
        _ text: String,
        error: FoodEntryFormError
    ) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value >= 0 else {
            throw error
        }
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

    private func parseOptionalNonNegativeDouble(
        _ text: String,
        error: FoodEntryFormError
    ) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value >= 0 else {
            throw error
        }
        return value
    }
}
