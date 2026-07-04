//
//  PlanEditSelectionChrome.swift
//  Fitness Coach
//
//  Forma — Shared selection chrome for Edit Plan cards and inputs.
//

import SwiftUI

enum PlanEditSelectionChrome {

    static func cardBackground(isSelected: Bool) -> Color {
        isSelected
            ? FormaPlanTokens.Color.planSelectedCardBackground
            : FormaPlanTokens.Color.planUnselectedCardBackground
    }

    static func cardStrokeColor(isSelected: Bool) -> Color {
        isSelected
            ? FormaPlanTokens.Color.planSelectedBorder
            : FormaPlanTokens.Color.planSubtleCardBorder
    }

    static func cardStrokeWidth(isSelected: Bool) -> CGFloat {
        isSelected ? 1.5 : 1
    }

    static func inputStrokeColor(isFocused: Bool, isInvalid: Bool) -> Color {
        if isInvalid {
            return FormaPlanTokens.Color.planDanger
        }
        if isFocused {
            return FormaPlanTokens.Color.planAccent
        }
        return FormaPlanTokens.Color.planInputBorder
    }

    static func inputStrokeWidth(isFocused: Bool, isInvalid: Bool) -> CGFloat {
        isFocused || isInvalid ? 1.5 : 1
    }
}
