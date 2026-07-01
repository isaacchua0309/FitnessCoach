//
//  OnboardingSavePlanPrivacyNote.swift
//  Fitness Coach
//
//  Forma — Privacy reassurance near save-plan Google sign-in.
//

import SwiftUI

struct OnboardingSavePlanPrivacyNote: View {
    var metrics: OnboardingSavePlanLayoutMetrics?

    private let copy = FormaProductCopy.Onboarding.V2.SavePlan.privacyNote

    var body: some View {
        Text(copy)
            .font(FormaTokens.Typography.caption2.weight(.medium))
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .multilineTextAlignment(.center)
            .lineLimit(metrics?.usesAccessibilityLayout == true ? 4 : 3)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(copy)
    }
}

#if DEBUG
#Preview {
    OnboardingSavePlanPrivacyNote()
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
