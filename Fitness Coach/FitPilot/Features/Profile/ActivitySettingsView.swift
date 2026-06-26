//
//  ActivitySettingsView.swift
//  Fitness Coach
//
//  FitPilot AI — Activity settings form section.
//

import SwiftUI

struct ActivitySettingsView: View {
    @Binding var activityLevel: ActivityLevel
    @Binding var trainingFrequencyPerWeekText: String
    @Binding var averageStepsText: String

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                FormaPickerRow(title: FormaProductCopy.ProfileForm.activityLevel, selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(ProfileFormatter.activityLevel(level)).tag(level)
                    }
                }
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.trainingDays,
                    placeholder: "3",
                    text: $trainingFrequencyPerWeekText,
                    keyboard: .numberPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.averageSteps,
                    placeholder: "5000",
                    text: $averageStepsText,
                    keyboard: .numberPad
                )
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
            .fitPilotFormSection()
        } header: {
            FitPilotSettingsSectionHeader(title: "Activity")
        }
    }
}

#Preview {
    Form {
        ActivitySettingsView(
            activityLevel: .constant(.moderatelyActive),
            trainingFrequencyPerWeekText: .constant("3"),
            averageStepsText: .constant("5000")
        )
    }
    .fitPilotDarkGroupedList()
}
