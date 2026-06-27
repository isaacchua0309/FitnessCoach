//
//  OnboardingFieldSummary.swift
//  Fitness Coach
//
//  Forma — Compact read-only or tappable value row for onboarding inputs.
//

import SwiftUI

struct OnboardingFieldSummary: View {
    let label: String
    let value: String
    var unit: String?
    var systemImage: String = "chevron.up.chevron.down"
    var showsDisclosure: Bool = true
    var action: (() -> Void)?

    private var displayValue: String {
        guard let unit, !unit.isEmpty else { return value }
        return "\(value) \(unit)"
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(action == nil ? "" : "Opens picker")
        .accessibilityAddTraits(action == nil ? [] : .isButton)
    }

    private var rowContent: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(displayValue)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if showsDisclosure, action != nil {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
        .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(FormaTokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous))
    }

    private var accessibilityLabel: String {
        "\(label), \(displayValue)"
    }
}

#Preview("Tappable") {
    OnboardingFieldSummary(
        label: "Height",
        value: "170",
        unit: "cm",
        action: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Read only") {
    OnboardingFieldSummary(
        label: "Goal weight",
        value: "68",
        unit: "kg",
        showsDisclosure: false,
        action: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
