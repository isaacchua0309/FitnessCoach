//
//  OnboardingAppleHealthStepView.swift
//  Fitness Coach
//
//  Forma — Apple Health connection prompt (read-only permission on Continue).
//

import SwiftUI

struct OnboardingAppleHealthStepView: View {
    var isRequestingPermission: Bool = false

    private let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            iconOrb

            benefitsCard

            Text(copy.optionalNote)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(copy.optionalNote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconOrb: some View {
        ZStack {
            Circle()
                .fill(FormaTokens.Color.accentMuted)
                .frame(width: 56, height: 56)

            if isRequestingPermission {
                SwiftUI.ProgressView()
                    .tint(OnboardingTheme.accent)
            } else {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
            }
        }
        .accessibilityHidden(true)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            ForEach(copy.benefits, id: \.self) { benefit in
                benefitRow(benefit)
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.benefitsAccessibilityLabel)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent.opacity(0.85))
                .padding(.top, 1)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: OnboardingLayout.selectionRowMinHeight, alignment: .center)
    }
}

#if DEBUG
#Preview("Apple Health") {
    OnboardingAppleHealthStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Apple Health — Requesting") {
    OnboardingAppleHealthStepView(isRequestingPermission: true)
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
