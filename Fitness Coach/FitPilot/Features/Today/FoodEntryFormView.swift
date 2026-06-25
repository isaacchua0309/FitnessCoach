//
//  FoodEntryFormView.swift
//  Fitness Coach
//
//  FitPilot AI — Form fields for manual food entry.
//

import SwiftUI

struct FoodEntryFormView: View {
    @Binding var formState: FoodEntryFormState

    var body: some View {
        Section("Food") {
            TextField("Food name", text: $formState.name)
                .textInputAutocapitalization(.words)
            MealTypePicker(mealType: $formState.mealType)
            TextField("Quantity (optional)", text: $formState.quantityText)
                .keyboardType(.decimalPad)
            TextField("Unit (optional)", text: $formState.unit)
                .textInputAutocapitalization(.never)
        }

        MacroInputSection(
            caloriesText: $formState.caloriesText,
            proteinText: $formState.proteinText,
            carbsText: $formState.carbsText,
            fatText: $formState.fatText
        )

        Section("Optional") {
            TextField("Fiber (g)", text: $formState.fiberText)
                .keyboardType(.decimalPad)
            TextField("Sodium (mg)", text: $formState.sodiumText)
                .keyboardType(.numberPad)
            TextField("Notes", text: $formState.notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }
}

#Preview {
    Form {
        FoodEntryFormView(formState: .constant(FoodEntryFormState()))
    }
}
