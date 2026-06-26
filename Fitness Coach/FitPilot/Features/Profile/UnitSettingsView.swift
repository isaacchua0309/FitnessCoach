//
//  UnitSettingsView.swift
//  Fitness Coach
//
//  FitPilot AI — Unit system settings form section.
//

import SwiftUI

struct UnitSettingsView: View {
    @Binding var unitSystem: UnitSystem

    var body: some View {
        Section {
            FormaPickerRow(title: FormaProductCopy.ProfileForm.unitSystem, selection: $unitSystem) {
                ForEach(UnitSystem.allCases, id: \.self) { system in
                    Text(ProfileFormatter.unitSystem(system)).tag(system)
                }
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
            .fitPilotFormSection()
        } header: {
            FitPilotSettingsSectionHeader(title: "Units")
        } footer: {
            Text("Values are stored in metric internally. Imperial is a display preference for now.")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
    }
}

#Preview {
    Form {
        UnitSettingsView(unitSystem: .constant(.metric))
    }
    .fitPilotDarkGroupedList()
}
