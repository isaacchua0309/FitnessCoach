//
//  OnboardingTextField.swift
//  Fitness Coach
//
//  FitPilot AI — Reusable onboarding input field.
//

import SwiftUI

struct OnboardingTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var helper: String?
    var trailingUnit: String?
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>?
    var isFocused: Bool = false
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            field

            if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        let textField = TextField(placeholder, text: $text, axis: axis)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .submitLabel(submitLabel)
            .onSubmit {
                onSubmit?()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(OnboardingTheme.primaryText)
            .tint(OnboardingTheme.accent)
            .accessibilityLabel(title)

        Group {
            if let trailingUnit {
                HStack(spacing: OnboardingLayout.compactLabelGap) {
                    if let lineLimit {
                        textField.lineLimit(lineLimit)
                    } else {
                        textField
                    }

                    Text(trailingUnit)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .accessibilityHidden(true)
                }
            } else if let lineLimit {
                textField.lineLimit(lineLimit)
            } else {
                textField
            }
        }
        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
        .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.1) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(
                    isFocused ? OnboardingTheme.selectedBorder : OnboardingTheme.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct OnboardingNumberField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var helper: String?
    var trailingUnit: String?
    var keyboard: UIKeyboardType = .numberPad
    var isFocused: Bool = false
    var onSubmit: (() -> Void)?

    var body: some View {
        OnboardingTextField(
            title: title,
            placeholder: placeholder,
            text: $text,
            helper: helper,
            trailingUnit: trailingUnit,
            keyboard: keyboard,
            isFocused: isFocused,
            submitLabel: .next,
            onSubmit: onSubmit
        )
    }
}
