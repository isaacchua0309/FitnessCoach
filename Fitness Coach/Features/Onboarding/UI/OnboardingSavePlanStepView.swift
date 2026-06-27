//
//  OnboardingSavePlanStepView.swift
//  Fitness Coach
//
//  Forma — Save plan + Google sign-in step for onboarding v2.
//

import SwiftUI

struct OnboardingSavePlanStepView: View {
    let requiresGoogleSignIn: Bool
    let isBusy: Bool
    let allowsLocalOnlyContinuation: Bool
    let errorMessage: String?
    let onContinue: () -> Void
    let onContinueWithoutAccount: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            Button(action: onBack) {
                Label(FormaProductCopy.Common.back, systemImage: "chevron.left")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(FormaProductCopy.Common.back)

            if requiresGoogleSignIn {
                preAuthContent
            } else {
                signedInContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var preAuthContent: some View {
        OnboardingInfoCard(
            title: FormaProductCopy.Onboarding.V2.SavePlan.planSavedOnDeviceTitle,
            message: FormaProductCopy.Onboarding.V2.SavePlan.localOnlyHint,
            icon: "iphone"
        )

        if let errorMessage {
            OnboardingWarningBanner(message: errorMessage)
        }

        VStack(spacing: FormaTokens.Spacing.sm) {
            FormaGoogleSignInButton(
                isLoading: isBusy,
                isDisabled: isBusy,
                action: onContinue,
                accessibilityHint: "Save your plan and sync with Google"
            )

            Text(FormaProductCopy.Onboarding.V2.SavePlan.trustNote)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.SavePlan.trustNote)

            if allowsLocalOnlyContinuation {
                Button(action: onContinueWithoutAccount) {
                    Text(FormaProductCopy.Onboarding.V2.SavePlan.continueWithoutAccountCTA)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .tint(OnboardingTheme.secondaryText)
                .disabled(isBusy)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.SavePlan.continueWithoutAccountCTA)
                .accessibilityHint("Use the app on this device without signing in")
            }
        }
    }

    @ViewBuilder
    private var signedInContent: some View {
        OnboardingInfoCard(
            title: FormaProductCopy.Onboarding.V2.SavePlan.planSavedOnDeviceTitle,
            message: FormaProductCopy.Onboarding.V2.SavePlan.signedInSubtitle,
            icon: "icloud.and.arrow.up"
        )

        if let errorMessage {
            OnboardingWarningBanner(message: errorMessage)
        }

        Button(action: onContinue) {
            Text(FormaProductCopy.Onboarding.V2.SavePlan.signedInContinueCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(OnboardingTheme.accent)
        .disabled(isBusy)
        .accessibilityLabel(FormaProductCopy.Onboarding.V2.SavePlan.signedInContinueCTA)
        .accessibilityHint("Save your plan to your Google account")
    }
}

#Preview("Sign-in required") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        allowsLocalOnlyContinuation: false,
        errorMessage: nil,
        onContinue: {},
        onContinueWithoutAccount: {},
        onBack: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Signed in") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: false,
        isBusy: false,
        allowsLocalOnlyContinuation: false,
        errorMessage: nil,
        onContinue: {},
        onContinueWithoutAccount: {},
        onBack: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Local-only available") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        allowsLocalOnlyContinuation: true,
        errorMessage: nil,
        onContinue: {},
        onContinueWithoutAccount: {},
        onBack: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
