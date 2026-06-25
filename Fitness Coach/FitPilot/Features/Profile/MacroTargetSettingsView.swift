//
//  MacroTargetSettingsView.swift
//  Fitness Coach
//
//  FitPilot AI — Macro and calorie target settings form section.
//

import SwiftUI

struct MacroTargetSettingsView: View {
    @Binding var calorieTargetText: String
    @Binding var proteinTargetText: String
    @Binding var carbTargetText: String
    @Binding var fatTargetText: String
    @Binding var expectedWeeklyWeightLossKgText: String
    @Binding var aggressiveness: CalorieAggressiveness

    let onRegenerate: () -> Void

    var body: some View {
        Section {
            TextField("Calorie target", text: $calorieTargetText)
                .keyboardType(.numberPad)
            TextField("Protein target (g)", text: $proteinTargetText)
                .keyboardType(.decimalPad)
            TextField("Carb target (g)", text: $carbTargetText)
                .keyboardType(.decimalPad)
            TextField("Fat target (g)", text: $fatTargetText)
                .keyboardType(.decimalPad)
            TextField("Expected weekly loss (kg)", text: $expectedWeeklyWeightLossKgText)
                .keyboardType(.decimalPad)

            Button {
                onRegenerate()
            } label: {
                Label("Regenerate Targets", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: {
            Text("Macro Targets")
        } footer: {
            Text("Manual edits are saved as-is. Regenerate to recalculate from your profile using \(ProfileFormatter.aggressiveness(aggressiveness).lowercased()) aggressiveness.")
        }
    }
}

#Preview {
    Form {
        MacroTargetSettingsView(
            calorieTargetText: .constant("1850"),
            proteinTargetText: .constant("144"),
            carbTargetText: .constant("180"),
            fatTargetText: .constant("58"),
            expectedWeeklyWeightLossKgText: .constant("0.5"),
            aggressiveness: .constant(.moderate),
            onRegenerate: {}
        )
    }
}
