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
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        let base = TextField(placeholder, text: $text, axis: axis)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .font(.body.weight(.medium))
            .foregroundStyle(OnboardingTheme.primaryText)
            .tint(OnboardingTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.border, lineWidth: 1)
            )
            .accessibilityLabel(title)

        if let lineLimit {
            base.lineLimit(lineLimit)
        } else {
            base
        }
    }
}
