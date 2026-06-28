//
//  OnboardingPlanStatusCard.swift
//  Fitness Coach
//
//  Forma — Positive or caution status for onboarding plan reveal.
//

import SwiftUI

struct OnboardingPlanStatusCard: View {
    let status: OnboardingPlanRevealStatus

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Label {
                Text(status.title)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: iconName)
            }

            if let body = status.body {
                Text(body)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(foregroundColor)
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch status.style {
        case .positive:
            return "checkmark.circle.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        }
    }

    private var foregroundColor: Color {
        switch status.style {
        case .positive:
            return OnboardingTheme.accent
        case .caution:
            return OnboardingTheme.warning
        }
    }

    private var backgroundColor: Color {
        switch status.style {
        case .positive:
            return OnboardingTheme.accent.opacity(0.12)
        case .caution:
            return OnboardingTheme.warning.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch status.style {
        case .positive:
            return OnboardingTheme.accent.opacity(0.28)
        case .caution:
            return OnboardingTheme.warning.opacity(0.32)
        }
    }

    private var accessibilityLabel: String {
        if let body = status.body {
            return "\(status.title). \(body)"
        }
        return status.title
    }
}

#Preview("Sustainable") {
    OnboardingPlanStatusCard(
        status: OnboardingPlanRevealStatus(
            title: FormaProductCopy.Onboarding.V2.PlanReveal.Status.sustainableTitle,
            body: nil,
            style: .positive
        )
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Caution") {
    OnboardingPlanStatusCard(
        status: OnboardingPlanRevealStatus(
            title: FormaProductCopy.Onboarding.V2.PlanReveal.Status.aggressiveDeficitTitle,
            body: FormaProductCopy.Onboarding.V2.PlanReveal.Status.aggressiveDeficitBody,
            style: .caution
        )
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
