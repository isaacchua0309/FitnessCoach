//
//  MealTypePicker.swift
//  Fitness Coach
//
//  FitPilot AI — Meal type picker for manual food entry.
//

import SwiftUI

struct MealTypePicker: View {
    @Binding var mealType: MealType?

    var body: some View {
        Picker("Meal Type", selection: mealTypeBinding) {
            ForEach(MealType.allCases, id: \.self) { type in
                Text(FoodEntryFormFormatter.mealTypeLabel(type)).tag(type)
            }
        }
    }

    private var mealTypeBinding: Binding<MealType> {
        Binding(
            get: { mealType ?? .unknown },
            set: { mealType = $0 }
        )
    }
}

#Preview {
    Form {
        MealTypePicker(mealType: .constant(.lunch))
    }
}
