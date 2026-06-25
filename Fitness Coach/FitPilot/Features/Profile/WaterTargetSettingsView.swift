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
        Section("Water Target") {
            TextField("Water target (ml)", text: $waterTargetMlText)
                .keyboardType(.numberPad)
        }
    }
}

#Preview {
    Form {
        WaterTargetSettingsView(waterTargetMlText: .constant("2520"))
    }
}
