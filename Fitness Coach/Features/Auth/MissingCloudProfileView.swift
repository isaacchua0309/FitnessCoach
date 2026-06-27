//
//  MissingCloudProfileView.swift
//  Fitness Coach
//
//  Forma — Post-sign-in interstitial when no cloud profile exists for this account.
//

import SwiftUI

struct MissingCloudProfileView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .accessibilityHidden(true)

                    Text(FormaProductCopy.Onboarding.V2.MissingCloudProfile.title)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(FormaProductCopy.Onboarding.V2.MissingCloudProfile.body)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                Button(action: onContinue) {
                    Text(FormaProductCopy.Onboarding.V2.MissingCloudProfile.continueCTA)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MissingCloudProfileView(onContinue: {})
}
