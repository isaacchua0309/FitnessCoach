//
//  FoodPreferencesView.swift
//  Fitness Coach
//
//  FitPilot AI — Diet preference settings form section.
//

import SwiftUI

struct FoodPreferencesView: View {
    @Binding var dietPreference: String

    var body: some View {
        Section {
            TextField("Diet preference", text: $dietPreference, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Food Preferences")
        } footer: {
            Text("Simple text preference for now. Advanced diet restrictions are not supported yet.")
        }
    }
}

#Preview {
    Form {
        FoodPreferencesView(dietPreference: .constant("High protein"))
    }
}
