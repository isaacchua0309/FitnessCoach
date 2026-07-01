//
//  OnboardingSavePlanInlineError.swift
//  Fitness Coach
//
//  Forma — Compact inline error for save-plan sign-in failures.
//

import SwiftUI

struct OnboardingSavePlanInlineError: View {
    let message: String

    var body: some View {
        Text(message)
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(message)
    }
}

#if DEBUG
#Preview {
    OnboardingSavePlanInlineError(
        message: FormaProductCopy.Onboarding.V2.SavePlan.signInRetryHeadline
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
