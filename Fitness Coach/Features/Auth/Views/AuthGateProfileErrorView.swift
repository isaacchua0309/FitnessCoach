//
//  AuthGateProfileErrorView.swift
//  Fitness Coach
//
//  Profile bootstrap error screen for the auth gate shell.
//

import SwiftUI

struct AuthGateProfileErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.warning)
                        .accessibilityHidden(true)

                    Text(FormaProductCopy.Onboarding.V2.BootstrapError.title)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                Button(FormaProductCopy.Onboarding.V2.BootstrapError.retryCTA, action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingTheme.ctaBackground)
                    .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                    .padding(.bottom, FormaTokens.Spacing.lg)
                    .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
