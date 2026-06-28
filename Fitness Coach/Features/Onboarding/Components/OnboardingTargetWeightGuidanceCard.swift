//
//  OnboardingTargetWeightGuidanceCard.swift
//  Fitness Coach
//
//  Forma — Live guidance card for target weight onboarding.
//

import SwiftUI

struct OnboardingTargetWeightGuidanceCard: View {
    let state: OnboardingTargetWeightGuidanceState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(state.title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(state.showsWarning ? OnboardingTheme.warning : OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(state.body)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let paceLine = state.paceLine {
                Text(paceLine)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }
}

#if DEBUG
#Preview("Target Weight Guidance") {
    OnboardingTargetWeightGuidanceCard(
        state: OnboardingTargetWeightGuidanceState(
            title: FormaProductCopy.Onboarding.Flow.TargetWeight.realisticTargetTitle,
            body: FormaProductCopy.Onboarding.Flow.TargetWeight.realisticTargetBody,
            paceLine: "Expected weekly pace: ~0.2–0.4 kg/week",
            showsWarning: false,
            accessibilityLabel: "Preview"
        )
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
