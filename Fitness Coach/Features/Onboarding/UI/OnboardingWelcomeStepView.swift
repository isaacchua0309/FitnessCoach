//
//  OnboardingWelcomeStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Welcome / promise step for onboarding (v2 step 1 + legacy v1).
//

import SwiftUI

struct OnboardingWelcomeStepView: View {
    var body: some View {
        Group {
            if OnboardingStepPolicy.isV2Enabled {
                v2PromiseContent
            } else {
                legacyWelcomeContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - V2 promise (step 1; title/subtitle live in stage progress header)

    private var v2PromiseContent: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            VStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(FormaProductCopy.Onboarding.V2.Welcome.valueCards, id: \.text) { card in
                    valueCard(text: card.text, icon: card.icon)
                }
            }

            Text(FormaProductCopy.Onboarding.V2.Welcome.microcopy)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.Welcome.microcopy)
        }
    }

    // MARK: - Legacy v1 welcome

    private var legacyWelcomeContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            FormaBrandMark(size: .large)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text(FormaProductCopy.Onboarding.welcomeHeadline)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(FormaProductCopy.Onboarding.welcomeBody)
                    .font(.body)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                ForEach(FormaProductCopy.Onboarding.welcomeFeatures, id: \.text) { feature in
                    valueCard(text: feature.text, icon: feature.icon)
                }
            }

            OnboardingInfoCard(
                title: FormaProductCopy.Onboarding.welcomeInfoTitle,
                message: FormaProductCopy.Onboarding.welcomeInfoMessage,
                icon: "clock.fill"
            )
        }
    }

    private func valueCard(text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .onboardingCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

#Preview("V2 promise") {
    OnboardingWelcomeStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Legacy") {
    OnboardingWelcomeStepView()
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
