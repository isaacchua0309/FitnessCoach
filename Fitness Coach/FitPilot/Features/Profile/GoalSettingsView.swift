//
//  GoalSettingsView.swift
//  Fitness Coach
//
//  FitPilot AI — Goal settings form section.
//

import SwiftUI

struct GoalSettingsView: View {
    @Binding var currentWeightKgText: String
    @Binding var goalWeightKgText: String
    @Binding var aggressiveness: CalorieAggressiveness

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.baselineWeight,
                    placeholder: "70",
                    text: $currentWeightKgText,
                    unit: FormaProductCopy.FoodForm.kgUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.goalWeight,
                    placeholder: "65",
                    text: $goalWeightKgText,
                    unit: FormaProductCopy.FoodForm.kgUnit,
                    keyboard: .decimalPad
                )
                FormaPickerRow(title: FormaProductCopy.ProfileForm.calorieAggressiveness, selection: $aggressiveness) {
                    ForEach(CalorieAggressiveness.allCases, id: \.self) { level in
                        Text(ProfileFormatter.aggressiveness(level)).tag(level)
                    }
                }
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
            .fitPilotFormSection()
        } header: {
            FitPilotSettingsSectionHeader(title: "Goals")
        } footer: {
            Text("Baseline weight is used for plan calculations. Log daily weigh-ins from Today or Coach — they are separate from this value.")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
    }
}

#Preview {
    Form {
        GoalSettingsView(
            currentWeightKgText: .constant("72"),
            goalWeightKgText: .constant("65"),
            aggressiveness: .constant(.moderate)
        )
    }
    .fitPilotDarkGroupedList()
}
