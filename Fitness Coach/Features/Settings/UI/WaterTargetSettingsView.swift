//
//  WaterTargetSettingsView.swift
//  Fitness Coach
//
//  FitPilot AI — Water target settings form section.
//

import SwiftUI

struct WaterTargetSettingsView: View {
    @Binding var waterTargetMlText: String

    var body: some View {
        Section {
            FormaLabeledNumberField(
                title: FormaProductCopy.ProfileForm.waterTarget,
                placeholder: "2500",
                text: $waterTargetMlText,
                unit: FormaProductCopy.FoodForm.mlUnit,
                keyboard: .numberPad
            )
            .padding(.vertical, FormaTokens.Spacing.xs)
            .fitPilotFormSection()
        } header: {
            FitPilotSettingsSectionHeader(title: "Water Target")
        }
    }
}

#Preview {
    Form {
        WaterTargetSettingsView(waterTargetMlText: .constant("2520"))
    }
    .fitPilotDarkGroupedList()
}
