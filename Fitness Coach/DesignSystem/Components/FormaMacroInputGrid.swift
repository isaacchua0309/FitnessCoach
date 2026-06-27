//
//  FormaMacroInputGrid.swift
//  Fitness Coach
//
//  Forma — Labeled macro input grid for food forms.
//

import SwiftUI

struct FormaMacroInputGrid: View {
    @Binding var caloriesText: String
    @Binding var proteinText: String
    @Binding var carbsText: String
    @Binding var fatText: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            FormaLabeledNumberField(
                title: FormaProductCopy.FoodForm.calories,
                placeholder: "0",
                text: $caloriesText,
                unit: FormaProductCopy.FoodForm.kcalUnit,
                keyboard: .numberPad
            )

            HStack(spacing: FormaTokens.Spacing.sm) {
                FormaInlineNumberField(
                    title: FormaProductCopy.FoodForm.protein,
                    text: $proteinText,
                    unit: FormaProductCopy.FoodForm.gramsUnit
                )
                FormaInlineNumberField(
                    title: FormaProductCopy.FoodForm.carbs,
                    text: $carbsText,
                    unit: FormaProductCopy.FoodForm.gramsUnit
                )
                FormaInlineNumberField(
                    title: FormaProductCopy.FoodForm.fat,
                    text: $fatText,
                    unit: FormaProductCopy.FoodForm.gramsUnit
                )
            }
        }
    }
}
