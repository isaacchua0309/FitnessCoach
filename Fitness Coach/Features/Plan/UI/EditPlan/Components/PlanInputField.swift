//
//  PlanInputField.swift
//  Fitness Coach
//
//  Forma — Large metric input with unit pill for Edit Plan.
//

import SwiftUI

struct PlanInputField: View {
    let model: PlanInputFieldDisplayModel
    @Binding var text: String

    private var showsValidation: Bool {
        model.validationMessage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(model.title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                TextField(model.placeholder, text: $text)
                    .font(valueFont)
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    .accessibilityLabel(inputAccessibilityLabel)
                    .accessibilityValue(fieldAccessibilityValue)

                if let unitLabel = model.unitLabel {
                    PlanMetricPill(text: unitLabel)
                }
            }
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: inputCornerRadius, style: .continuous)
                    .fill(FormaPlanTokens.Color.planInputBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: inputCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }

            if let validationMessage = model.validationMessage {
                Text(validationMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        "\(FormaProductCopy.PlanEditAccessibility.errorPrefix). \(validationMessage)"
                    )
            }
        }
        .accessibilityElement(children: .contain)
        .planEditAnnounces(
            model.validationMessage.map {
                "\(FormaProductCopy.PlanEditAccessibility.errorPrefix). \($0)"
            }
        )
    }

    private var inputAccessibilityLabel: String {
        FormaProductCopy.PlanEditAccessibility.fieldLabel(
            title: model.title,
            unit: model.unitLabel
        )
    }

    private var fieldAccessibilityValue: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return FormaProductCopy.PlanEditAccessibility.emptyFieldValue
        }
        if let unitLabel = model.unitLabel {
            return "\(trimmed) \(unitLabel)"
        }
        return trimmed
    }

    private var valueFont: Font {
        switch model.valueStyle {
        case .title:
            return .title.weight(.bold).design(.rounded)
        case .largeTitle:
            return .largeTitle.weight(.bold).design(.rounded)
        }
    }

    private var inputCornerRadius: CGFloat {
        model.usesCompactChrome ? FormaTokens.Radius.compact : FormaTokens.Radius.card
    }

    private var borderColor: Color {
        PlanEditSelectionChrome.inputStrokeColor(
            isFocused: model.isFocused,
            isInvalid: showsValidation
        )
    }

    private var borderWidth: CGFloat {
        PlanEditSelectionChrome.inputStrokeWidth(
            isFocused: model.isFocused,
            isInvalid: showsValidation
        )
    }
}

#if DEBUG
#Preview {
    PlanInputField(
        model: PlanInputFieldDisplayModel(
            title: "Height",
            placeholder: "175",
            unitLabel: "cm",
            isFocused: true
        ),
        text: .constant("175")
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
