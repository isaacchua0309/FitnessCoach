//
//  OnboardingV4PlaceholderStepView.swift
//  Fitness Coach
//
//  Forma — Temporary placeholder content for v4 steps pending final UI.
//

import SwiftUI

struct OnboardingV4PlaceholderStepView: View {
    let step: OnboardingV4Step

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            Text(step.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Placeholder — final UI coming soon.")
                .font(.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .padding(.top, FormaTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingV4PlaceholderStepView(step: .heightWeight)
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
