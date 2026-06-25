//
//  MacroInputSection.swift
//  Fitness Coach
//
//  FitPilot AI — Macro text fields for manual food entry.
//

import SwiftUI

struct MacroInputSection: View {
    @Binding var caloriesText: String
    @Binding var proteinText: String
    @Binding var carbsText: String
    @Binding var fatText: String

    var body: some View {
        Section("Macros") {
            TextField("Calories", text: $caloriesText)
                .keyboardType(.numberPad)
            TextField("Protein (g)", text: $proteinText)
                .keyboardType(.decimalPad)
            TextField("Carbs (g)", text: $carbsText)
                .keyboardType(.decimalPad)
            TextField("Fat (g)", text: $fatText)
                .keyboardType(.decimalPad)
        }
    }
}

#Preview {
    Form {
        MacroInputSection(
            caloriesText: .constant("413"),
            proteinText: .constant("78"),
            carbsText: .constant("0"),
            fatText: .constant("4")
        )
    }
}
