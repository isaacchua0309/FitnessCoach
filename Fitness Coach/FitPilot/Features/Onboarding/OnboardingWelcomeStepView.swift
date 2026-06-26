//
//  OnboardingWelcomeStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Welcome step for onboarding.
//

import SwiftUI

struct OnboardingWelcomeStepView: View {
    var body: some View {
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
                    featureRow(feature.text, icon: feature.icon)
                }
            }

            OnboardingInfoCard(
                title: FormaProductCopy.Onboarding.welcomeInfoTitle,
                message: FormaProductCopy.Onboarding.welcomeInfoMessage,
                icon: "clock.fill"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .onboardingCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingWelcomeStepView()
        .padding()
}
