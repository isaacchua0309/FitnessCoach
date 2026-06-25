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
            Picker("Unit system", selection: $unitSystem) {
                ForEach(UnitSystem.allCases, id: \.self) { system in
                    Text(ProfileFormatter.unitSystem(system)).tag(system)
                }
            }
        } header: {
            Text("Units")
        } footer: {
            Text("Values are stored in metric internally. Imperial is a display preference for now.")
        }
    }
}

#Preview {
    Form {
        UnitSettingsView(unitSystem: .constant(.metric))
    }
}
