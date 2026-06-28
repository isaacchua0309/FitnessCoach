//
//  OnboardingPlanBlueprintInsightCard.swift
//  Fitness Coach
//
//  Forma — Compact trust line for plan blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintTrustLine: View {
    let copy: String

    var body: some View {
        Text(copy)
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(copy)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintTrustLine(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Insight.loss
    )
    .padding(.horizontal)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
