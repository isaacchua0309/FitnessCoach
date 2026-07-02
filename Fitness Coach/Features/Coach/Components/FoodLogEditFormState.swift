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

    var portionLine: String {
        FoodComponentDisplayFormatter.portionLine(snapshotComponent)
    }

    private var snapshotComponent: FoodComponent {
        let trimmedQuantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity = trimmedQuantity.isEmpty ? nil : Double(trimmedQuantity)

        return FoodComponent(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit.isEmpty ? nil : unit,
            preparationState: preparationState.isEmpty ? nil : preparationState,
            calories: Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            protein: Double(proteinText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            carbs: Double(carbsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            fat: Double(fatText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            sourceText: sourceText.isEmpty ? nil : sourceText
        )
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
    var totalCaloriesText: String
    var totalProteinText: String
    var totalCarbsText: String
    var totalFatText: String

    init(mealDraft: FoodLogDraft) {
        mealType = mealDraft.mealType
        displayName = FoodMealDisplayNameFormatter.readableDisplayName(
            proposed: mealDraft.displayName,
            components: mealDraft.components
        )
        componentStates = mealDraft.components.map(FoodComponentFormState.init(component:))
        totalCaloriesText = "\(mealDraft.totalCalories)"
        totalProteinText = FoodEntryFormFormatter.formatMacro(mealDraft.totalProtein)
        totalCarbsText = FoodEntryFormFormatter.formatMacro(mealDraft.totalCarbs)
        totalFatText = FoodEntryFormFormatter.formatMacro(mealDraft.totalFat)
    }

    init(foodDraft: FoodDraft) {
        self.init(mealDraft: FoodLogDraftMapper.fromLegacyDraft(foodDraft))
    }

    var isMultiComponent: Bool {
        componentStates.count > 1
    }

    var totalCalories: Int {
        Int(totalCaloriesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
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

        let components: [FoodComponent]
        if isMultiComponent {
            components = try scaleComponentsToMatchTotals(
                originals: original.components,
                targetCalories: try parseNonNegativeInt(totalCaloriesText),
                targetProtein: try parseMacro(totalProteinText, error: .invalidProtein),
                targetCarbs: try parseMacro(totalCarbsText, error: .invalidCarbs),
                targetFat: try parseMacro(totalFatText, error: .invalidFat),
                confidence: original.confidence
            )
        } else {
            components = try componentStates.map {
                try $0.makeComponent(confidence: original.confidence)
            }
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
        let originalName = FoodMealDisplayNameFormatter.readableDisplayName(
            proposed: original.displayName,
            components: original.components
        )
        guard rebuilt.displayName == originalName.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        guard rebuilt.mealType == original.mealType else { return false }
        guard rebuilt.notes == original.notes else { return false }

        if isMultiComponent {
            return rebuilt.totalCalories == original.totalCalories
                && rebuilt.totalProtein == original.totalProtein
                && rebuilt.totalCarbs == original.totalCarbs
                && rebuilt.totalFat == original.totalFat
                && componentMetadataMatches(rebuilt.components, original.components)
        }

        return rebuilt.components == original.components
    }

    private func componentMetadataMatches(
        _ rebuilt: [FoodComponent],
        _ original: [FoodComponent]
    ) -> Bool {
        guard rebuilt.count == original.count else { return false }
        return zip(rebuilt, original).allSatisfy { left, right in
            left.id == right.id
                && left.name == right.name
                && left.quantity == right.quantity
                && left.unit == right.unit
                && left.preparationState == right.preparationState
                && left.sourceText == right.sourceText
        }
    }

    private func scaleComponentsToMatchTotals(
        originals: [FoodComponent],
        targetCalories: Int,
        targetProtein: Double,
        targetCarbs: Double,
        targetFat: Double,
        confidence: ConfidenceLevel
    ) throws -> [FoodComponent] {
        guard !originals.isEmpty else { throw FoodEntryFormError.missingName }

        let originalCalories = originals.reduce(0) { $0 + $1.calories }
        let originalProtein = originals.reduce(0) { $0 + $1.protein }
        let originalCarbs = originals.reduce(0) { $0 + $1.carbs }
        let originalFat = originals.reduce(0) { $0 + $1.fat }

        let calorieRatio = ratio(
            target: Double(targetCalories),
            original: Double(originalCalories),
            fallback: 1
        )
        let proteinRatio = ratio(target: targetProtein, original: originalProtein, fallback: calorieRatio)
        let carbsRatio = ratio(target: targetCarbs, original: originalCarbs, fallback: calorieRatio)
        let fatRatio = ratio(target: targetFat, original: originalFat, fallback: calorieRatio)

        var scaled = originals.map { component in
            var copy = component
            copy.calories = Int(round(Double(component.calories) * calorieRatio))
            copy.protein = component.protein * proteinRatio
            copy.carbs = component.carbs * carbsRatio
            copy.fat = component.fat * fatRatio
            copy.confidence = confidence
            return copy
        }

        adjustRoundingDrift(
            on: &scaled,
            targetCalories: targetCalories,
            targetProtein: targetProtein,
            targetCarbs: targetCarbs,
            targetFat: targetFat
        )
        return scaled
    }

    private func ratio(target: Double, original: Double, fallback: Double) -> Double {
        guard original > 0 else { return fallback }
        return target / original
    }

    private func adjustRoundingDrift(
        on components: inout [FoodComponent],
        targetCalories: Int,
        targetProtein: Double,
        targetCarbs: Double,
        targetFat: Double
    ) {
        guard let lastIndex = components.indices.last else { return }

        let calorieDrift = targetCalories - components.reduce(0) { $0 + $1.calories }
        components[lastIndex].calories = max(0, components[lastIndex].calories + calorieDrift)

        let proteinDrift = targetProtein - components.reduce(0) { $0 + $1.protein }
        components[lastIndex].protein = max(0, components[lastIndex].protein + proteinDrift)

        let carbsDrift = targetCarbs - components.reduce(0) { $0 + $1.carbs }
        components[lastIndex].carbs = max(0, components[lastIndex].carbs + carbsDrift)

        let fatDrift = targetFat - components.reduce(0) { $0 + $1.fat }
        components[lastIndex].fat = max(0, components[lastIndex].fat + fatDrift)
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
}
