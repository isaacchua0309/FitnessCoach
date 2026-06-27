//
//  OnboardingFeedbackCard.swift
//  Fitness Coach
//
//  Forma — Calm micro-validation after onboarding selections.
//

import SwiftUI

struct OnboardingFeedbackCard: View {
    enum Style: Equatable {
        case guidance
        case info
        case success

        var iconColor: Color {
            switch self {
            case .guidance, .info:
                return OnboardingTheme.accent
            case .success:
                return FormaTokens.Color.success
            }
        }

        var backgroundColor: Color {
            switch self {
            case .guidance:
                return OnboardingTheme.accent.opacity(0.12)
            case .info:
                return OnboardingTheme.card
            case .success:
                return FormaTokens.Color.success.opacity(0.12)
            }
        }

        var borderColor: Color {
            switch self {
            case .guidance:
                return OnboardingTheme.accent.opacity(0.28)
            case .info:
                return OnboardingTheme.border
            case .success:
                return FormaTokens.Color.success.opacity(0.28)
            }
        }
    }

    let icon: String
    let title: String
    let message: String
    var style: Style = .guidance

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(style.iconColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(style.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(style.borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview("Guidance") {
    OnboardingFeedbackCard(
        icon: "checkmark.circle.fill",
        title: FormaProductCopy.Onboarding.V2.BodyFeedback.title,
        message: FormaProductCopy.Onboarding.V2.BodyFeedback.message,
        style: .guidance
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Success") {
    OnboardingFeedbackCard(
        icon: "sparkles",
        title: FormaProductCopy.Onboarding.V2.Motivation.feedbackTitle,
        message: FormaProductCopy.Onboarding.V2.Motivation.defaultFeedback,
        style: .success
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
