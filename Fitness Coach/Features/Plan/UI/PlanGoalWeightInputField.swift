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

    private var showsValidation: Bool {
        validationMessage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(FormaProductCopy.PlanEditTarget.targetWeightTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                TextField("0", text: $text)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel(FormaProductCopy.PlanEditTarget.targetWeightTitle)

                Text(unitLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(FormaPlanTokens.Color.planAccentSoft)
                    }
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .fill(FormaPlanTokens.Color.planInputBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(
                        showsValidation
                            ? FormaPlanTokens.Color.planDanger
                            : FormaPlanTokens.Color.planCardBorder.opacity(0.55),
                        lineWidth: showsValidation ? 1.5 : 1
                    )
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(validationMessage)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
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
#endif
