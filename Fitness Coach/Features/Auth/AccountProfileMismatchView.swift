//
//  AccountProfileMismatchView.swift
//  Fitness Coach
//
//  Forma — Resolve a local profile that belongs to a different Google account.
//

import SwiftUI

struct AccountProfileMismatchView: View {
    let isResolving: Bool
    let onRestoreGooglePlan: () -> Void
    let onUseDeviceProfile: () -> Void
    let onSignOut: () -> Void

    private let copy = FormaProductCopy.Onboarding.V2.AccountProfileMismatch.self

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
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
                    Button(action: onRestoreGooglePlan) {
                        Group {
                            if isResolving {
                                SwiftUI.ProgressView()
                                    .tint(OnboardingTheme.ctaText)
                            } else {
                                Text(copy.restoreCTA)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingTheme.ctaBackground)
                    .disabled(isResolving)

                    Button(action: onUseDeviceProfile) {
                        Text(copy.useDeviceProfileCTA)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(OnboardingTheme.secondaryText)
                    .disabled(isResolving)

                    Button(action: onSignOut) {
                        Text(copy.signOutCTA)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.tertiaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .disabled(isResolving)
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
    AccountProfileMismatchView(
        isResolving: false,
        onRestoreGooglePlan: {},
        onUseDeviceProfile: {},
        onSignOut: {}
    )
    .formaThemePreview()
}
