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
        Section("Goals") {
            TextField("Current weight (kg)", text: $currentWeightKgText)
                .keyboardType(.decimalPad)

            TextField("Goal weight (kg)", text: $goalWeightKgText)
                .keyboardType(.decimalPad)

            Picker("Calorie aggressiveness", selection: $aggressiveness) {
                ForEach(CalorieAggressiveness.allCases, id: \.self) { level in
                    Text(ProfileFormatter.aggressiveness(level)).tag(level)
                }
            }
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
}
