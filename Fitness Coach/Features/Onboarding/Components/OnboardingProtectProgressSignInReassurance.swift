//
//  OnboardingProtectProgressSignInReassurance.swift
//  Fitness Coach
//
//  Forma — Lightweight reassurance when protect-progress sign-in does not finish.
//

import SwiftUI

struct OnboardingProtectProgressSignInReassurance: View {
    private let copy = FormaProductCopy.Onboarding.V2.SavePlan.self

    var body: some View {
        VStack(spacing: 3) {
            Text(copy.signInRetryHeadline)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(copy.signInRetryReassurance)
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.signInRetryInvitation)
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy.signInRetryAccessibilitySummary)
    }
}

#if DEBUG
#Preview {
    OnboardingProtectProgressSignInReassurance()
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
