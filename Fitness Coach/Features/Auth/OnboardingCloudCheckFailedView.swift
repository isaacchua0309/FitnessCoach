//
//  OnboardingCloudCheckFailedView.swift
//  Fitness Coach
//
//  Forma — Retry UI when cloud profile check fails during onboarding completion.
//

import SwiftUI

struct OnboardingCloudCheckFailedView: View {
    let onRetry: () -> Void

    private let copy = FormaProductCopy.Onboarding.V2.CloudCheckFailed.self

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

                    Text(copy.title)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(copy.body)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                Spacer(minLength: 0)

                Button(action: onRetry) {
                    Text(copy.retryCTA)
                        .frame(maxWidth: .infinity)
                }
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

#Preview {
    OnboardingCloudCheckFailedView(onRetry: {})
        .formaThemePreview()
}
