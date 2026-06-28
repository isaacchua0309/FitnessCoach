//
//  CloudProfileUploadFailedView.swift
//  Fitness Coach
//
//  Forma — Local plan saved but Google backup failed (Stage 8).
//

import SwiftUI

struct CloudProfileUploadFailedView: View {
    let isRetrying: Bool
    let onRetry: () -> Void
    let onContinue: () -> Void

    private let copy = FormaProductCopy.Onboarding.V2.CloudUploadFailed.self

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "icloud.slash")
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

                VStack(spacing: FormaTokens.Spacing.sm) {
                    Button(action: onRetry) {
                        Group {
                            if isRetrying {
                                SwiftUI.ProgressView()
                                    .tint(OnboardingTheme.ctaText)
                            } else {
                                Text(copy.retryCTA)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingTheme.ctaBackground)
                    .disabled(isRetrying)

                    Button(action: onContinue) {
                        Text(copy.continueCTA)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(OnboardingTheme.secondaryText)
                    .disabled(isRetrying)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    CloudProfileUploadFailedView(isRetrying: false, onRetry: {}, onContinue: {})
        .formaThemePreview()
}
