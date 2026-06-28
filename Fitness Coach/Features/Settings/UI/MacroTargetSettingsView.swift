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
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.calorieTarget,
                    placeholder: "2000",
                    text: $calorieTargetText,
                    unit: FormaProductCopy.FoodForm.kcalUnit,
                    keyboard: .numberPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.proteinTarget,
                    placeholder: "140",
                    text: $proteinTargetText,
                    unit: FormaProductCopy.FoodForm.gramsUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.carbTarget,
                    placeholder: "200",
                    text: $carbTargetText,
                    unit: FormaProductCopy.FoodForm.gramsUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.fatTarget,
                    placeholder: "60",
                    text: $fatTargetText,
                    unit: FormaProductCopy.FoodForm.gramsUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.weeklyLoss,
                    placeholder: "0.5",
                    text: $expectedWeeklyWeightLossKgText,
                    unit: FormaProductCopy.FoodForm.kgUnit,
                    keyboard: .decimalPad
                )

                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate Targets", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.accent)
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
            .fitPilotFormSection()
        } header: {
            FitPilotSettingsSectionHeader(title: "Macro Targets")
        } footer: {
            Text("Manual edits are saved as-is. Regenerate to recalculate from your profile and pace settings.")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
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
    .fitPilotGroupedList()
}
