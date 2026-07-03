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

    private var showsValidation: Bool {
        validationMessage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                TextField(placeholder, text: $text)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    .accessibilityLabel(title)

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
                    .stroke(borderColor, lineWidth: borderWidth)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planDanger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var borderColor: Color {
        if showsValidation {
            return FormaPlanTokens.Color.planDanger
        }
        if isFocused {
            return FormaPlanTokens.Color.planAccent
        }
        return FormaPlanTokens.Color.planCardBorder.opacity(0.55)
    }

    private var borderWidth: CGFloat {
        showsValidation || isFocused ? 1.5 : 1
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
