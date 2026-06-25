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
        Section("Activity") {
            Picker("Activity level", selection: $activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(ProfileFormatter.activityLevel(level)).tag(level)
                }
            }

            TextField("Training days per week", text: $trainingFrequencyPerWeekText)
                .keyboardType(.numberPad)

            TextField("Average steps per day", text: $averageStepsText)
                .keyboardType(.numberPad)
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
}
