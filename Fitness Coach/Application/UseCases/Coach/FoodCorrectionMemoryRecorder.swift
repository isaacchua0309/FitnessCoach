//
//  FoodCorrectionMemoryRecorder.swift
//  Fitness Coach
//
//  Forma — Detects and records food estimate corrections for future Coach context.
//

import Foundation

enum FoodCorrectionMemoryRecorder {

    static func recordIfNeeded(
        before: FoodLogDraft,
        after: FoodLogDraft,
        source: FoodCorrectionMemorySource,
        store: FoodCorrectionMemoryStoring?
    ) async {
        guard let store else { return }
        guard !before.isApproximatelyEqual(to: after) else { return }

        let entries = detectCorrections(before: before, after: after, source: source)
        for entry in entries {
            try? await store.record(entry)
        }
    }

    static func recordPostLogEditIfNeeded(
        before: FoodEntry,
        after: FoodEntry,
        store: FoodCorrectionMemoryStoring?
    ) async {
        guard let store else { return }
        let beforeDraft = FoodLogDraftMapper.fromFoodEntry(before)
        let afterDraft = FoodLogDraftMapper.fromFoodEntry(after)
        await recordIfNeeded(
            before: beforeDraft,
            after: afterDraft,
            source: .postLogEdit,
            store: store
        )
    }

    // MARK: - Detection

    private static func detectCorrections(
        before: FoodLogDraft,
        after: FoodLogDraft,
        source: FoodCorrectionMemorySource
    ) -> [FoodCorrectionMemoryEntry] {
        var entries: [FoodCorrectionMemoryEntry] = []

        if before.displayName != after.displayName {
            entries.append(
                makeEntry(
                    before: before,
                    after: after,
                    source: source,
                    type: .cookingMethodChanged,
                    summary: "User corrected \(before.displayName) to \(after.displayName).",
                    componentName: after.displayName
                )
            )
        }

        let beforeComponents = Dictionary(uniqueKeysWithValues: before.components.map {
            (normalizedComponentName($0.name), $0)
        })
        let afterComponents = Dictionary(uniqueKeysWithValues: after.components.map {
            (normalizedComponentName($0.name), $0)
        })

        for (key, afterComponent) in afterComponents where beforeComponents[key] == nil {
            entries.append(
                makeEntry(
                    before: before,
                    after: after,
                    source: source,
                    type: sauceOrOilType(for: afterComponent.name),
                    summary: "User often adds \(afterComponent.name) to \(before.displayName).",
                    componentName: afterComponent.name,
                    amountHint: portionHint(for: afterComponent)
                )
            )
        }

        for (key, beforeComponent) in beforeComponents where afterComponents[key] == nil {
            entries.append(
                makeEntry(
                    before: before,
                    after: after,
                    source: source,
                    type: .componentRemoved,
                    summary: "User removed \(beforeComponent.name) from \(before.displayName).",
                    componentName: beforeComponent.name
                )
            )
        }

        for (key, afterComponent) in afterComponents {
            guard let beforeComponent = beforeComponents[key] else { continue }

            if quantityChanged(beforeComponent, afterComponent) {
                entries.append(
                    makeEntry(
                        before: before,
                        after: after,
                        source: source,
                        type: .portionAdjustment,
                        summary: portionSummary(
                            foodName: before.displayName,
                            componentName: afterComponent.name,
                            before: beforeComponent,
                            after: afterComponent
                        ),
                        componentName: afterComponent.name,
                        amountHint: portionHint(for: afterComponent)
                    )
                )
            } else if preparationChanged(beforeComponent, afterComponent) {
                entries.append(
                    makeEntry(
                        before: before,
                        after: after,
                        source: source,
                        type: .cookingMethodChanged,
                        summary: "User corrected \(afterComponent.name) preparation for \(before.displayName).",
                        componentName: afterComponent.name,
                        amountHint: afterComponent.preparationState
                    )
                )
            } else if caloriesChanged(beforeComponent, afterComponent) {
                entries.append(
                    makeEntry(
                        before: before,
                        after: after,
                        source: source,
                        type: calorieType(for: afterComponent.name),
                        summary: calorieSummary(
                            foodName: before.displayName,
                            componentName: afterComponent.name,
                            before: beforeComponent.calories,
                            after: afterComponent.calories
                        ),
                        componentName: afterComponent.name,
                        beforeCalories: beforeComponent.calories,
                        afterCalories: afterComponent.calories
                    )
                )
            } else if macrosChanged(beforeComponent, afterComponent) {
                entries.append(
                    makeEntry(
                        before: before,
                        after: after,
                        source: source,
                        type: .macroAdjustment,
                        summary: "User adjusted macros for \(afterComponent.name) in \(before.displayName).",
                        componentName: afterComponent.name
                    )
                )
            }
        }

        if entries.isEmpty, before.totalCalories != after.totalCalories {
            entries.append(
                makeEntry(
                    before: before,
                    after: after,
                    source: source,
                    type: .calorieOverride,
                    summary: "User corrected \(before.displayName) calories from about \(before.totalCalories) to \(after.totalCalories) kcal.",
                    beforeCalories: before.totalCalories,
                    afterCalories: after.totalCalories
                )
            )
        }

        return uniqueEntries(entries)
    }

    // MARK: - Helpers

    private static func makeEntry(
        before: FoodLogDraft,
        after: FoodLogDraft,
        source: FoodCorrectionMemorySource,
        type: FoodCorrectionType,
        summary: String,
        componentName: String? = nil,
        amountHint: String? = nil,
        beforeCalories: Int? = nil,
        afterCalories: Int? = nil
    ) -> FoodCorrectionMemoryEntry {
        FoodCorrectionMemoryEntry(
            originalFoodName: before.displayName,
            correctedFoodName: after.displayName == before.displayName ? nil : after.displayName,
            correctionType: type,
            correctionSummary: summary,
            beforeCalories: beforeCalories ?? (before.totalCalories > 0 ? before.totalCalories : nil),
            afterCalories: afterCalories ?? (after.totalCalories > 0 ? after.totalCalories : nil),
            componentName: componentName,
            amountHint: amountHint,
            source: source
        )
    }

    private static func portionSummary(
        foodName: String,
        componentName: String,
        before: FoodComponent,
        after: FoodComponent
    ) -> String {
        if let hint = portionHint(for: after) {
            return "User corrected \(componentName) portion to \(hint) for \(foodName)."
        }
        return "User corrected \(componentName) portion for \(foodName)."
    }

    private static func calorieSummary(
        foodName: String,
        componentName: String,
        before: Int,
        after: Int
    ) -> String {
        "User corrected \(componentName) in \(foodName) from about \(before) to \(after) kcal."
    }

    private static func portionHint(for component: FoodComponent) -> String? {
        if let quantity = component.quantity, let unit = component.unit, !unit.isEmpty {
            return "\(FoodEntryFormFormatter.formatOptionalDouble(quantity) ?? String(quantity)) \(unit)"
        }
        if let quantity = component.quantity {
            return FoodEntryFormFormatter.formatOptionalDouble(quantity) ?? String(quantity)
        }
        if let preparation = component.preparationState, !preparation.isEmpty {
            return preparation
        }
        return nil
    }

    private static func normalizedComponentName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func quantityChanged(_ before: FoodComponent, _ after: FoodComponent) -> Bool {
        before.quantity != after.quantity || before.unit != after.unit
    }

    private static func preparationChanged(_ before: FoodComponent, _ after: FoodComponent) -> Bool {
        before.preparationState != after.preparationState
    }

    private static func caloriesChanged(_ before: FoodComponent, _ after: FoodComponent) -> Bool {
        before.calories != after.calories
    }

    private static func macrosChanged(_ before: FoodComponent, _ after: FoodComponent) -> Bool {
        before.protein != after.protein
            || before.carbs != after.carbs
            || before.fat != after.fat
    }

    private static func sauceOrOilType(for name: String) -> FoodCorrectionType {
        let lowered = name.lowercased()
        if lowered.contains("sauce") || lowered.contains("oil") || lowered.contains("chili") {
            return .sauceOrOilAdjustment
        }
        return .componentAdded
    }

    private static func calorieType(for name: String) -> FoodCorrectionType {
        sauceOrOilType(for: name) == .sauceOrOilAdjustment ? .sauceOrOilAdjustment : .calorieOverride
    }

    private static func uniqueEntries(_ entries: [FoodCorrectionMemoryEntry]) -> [FoodCorrectionMemoryEntry] {
        var seen = Set<String>()
        return entries.filter { entry in
            let key = entry.mergeKey
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

private extension FoodLogDraft {
    func isApproximatelyEqual(to other: FoodLogDraft) -> Bool {
        displayName == other.displayName
            && totalCalories == other.totalCalories
            && components.count == other.components.count
            && zip(components, other.components).allSatisfy { lhs, rhs in
                lhs.name == rhs.name
                    && lhs.calories == rhs.calories
                    && lhs.quantity == rhs.quantity
                    && lhs.unit == rhs.unit
                    && lhs.preparationState == rhs.preparationState
                    && lhs.protein == rhs.protein
                    && lhs.carbs == rhs.carbs
                    && lhs.fat == rhs.fat
            }
    }
}
