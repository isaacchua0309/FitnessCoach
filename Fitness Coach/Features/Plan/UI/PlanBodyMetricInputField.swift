//
//  PlanBodyMetricInputField.swift
//  Fitness Coach
//
//  Forma — Large metric input with unit chip for Edit Plan.
//

import SwiftUI

struct PlanBodyMetricInputField: View {
    let title: String
    @Binding var text: String
    let unitLabel: String
    let placeholder: String
    let validationMessage: String?
    let isFocused: Bool

    var body: some View {
        PlanInputField(
            model: PlanInputFieldDisplayModel(
                title: title,
                placeholder: placeholder,
                unitLabel: unitLabel,
                validationMessage: validationMessage,
                isFocused: isFocused,
                valueStyle: .title
            ),
            text: $text
        )
    }
}

#if DEBUG
#Preview {
    PlanBodyMetricInputField(
        title: "Height",
        text: .constant("175"),
        unitLabel: "cm",
        placeholder: "175",
        validationMessage: nil,
        isFocused: true
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
