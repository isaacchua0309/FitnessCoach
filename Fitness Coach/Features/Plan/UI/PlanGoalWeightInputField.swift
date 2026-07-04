//
//  PlanGoalWeightInputField.swift
//  Fitness Coach
//
//  Forma — Large target weight input for Edit Plan.
//

import SwiftUI

struct PlanGoalWeightInputField: View {
    @Binding var text: String
    let unitSystem: UnitSystem
    let validationMessage: String?

    private var unitLabel: String {
        OnboardingFormatter.weightUnitAbbreviation(for: unitSystem)
    }

    var body: some View {
        PlanInputField(
            model: PlanInputFieldDisplayModel(
                title: FormaProductCopy.PlanEditTarget.targetWeightTitle,
                placeholder: "0",
                unitLabel: unitLabel,
                validationMessage: validationMessage,
                isFocused: false,
                valueStyle: .largeTitle
            ),
            text: $text
        )
    }
}

#Preview {
    PlanGoalWeightInputField(
        text: .constant("72"),
        unitSystem: .metric,
        validationMessage: nil
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
