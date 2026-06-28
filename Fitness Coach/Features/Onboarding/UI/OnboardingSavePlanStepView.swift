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
    var planRecap: OnboardingPlanRevealState?
    var usesCompactLayout: Bool = false
    let onContinue: () -> Void
    let onContinueWithoutAccount: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            Button(action: onBack) {
                Label(FormaProductCopy.Common.back, systemImage: "chevron.left")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(FormaProductCopy.Common.back)

            if usesCompactLayout {
                compactContent
            } else if requiresGoogleSignIn {
                preAuthContent
            } else {
                signedInContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - V3 compact

    @ViewBuilder
    private var compactContent: some View {
        let copy = FormaProductCopy.Onboarding.V3.SavePlan.self
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(copy.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(copy.subtitle)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let planRecap {
                planRecapCard(planRecap)
            }

            if let errorMessage {
                OnboardingWarningBanner(message: errorMessage)
            }

            if requiresGoogleSignIn {
                FormaGoogleSignInButton(
                    isLoading: isBusy,
                    isDisabled: isBusy,
                    action: onContinue,
                    accessibilityHint: "Save your plan and sync with Google"
                )

                Text(copy.trustNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(copy.trustNote)

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
            } else {
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
    }

    private func planRecapCard(_ state: OnboardingPlanRevealState) -> some View {
        let copy = FormaProductCopy.Onboarding.V3.SavePlan.self
        return VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(copy.recapSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)

            Text(state.dailyCalorieLabel)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text(state.goalProgressLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCompactCard(selected: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.recapSectionTitle), \(state.dailyCalorieLabel), goal \(state.goalProgressLabel)")
    }

    // MARK: - V2 standard

    @ViewBuilder
    private var preAuthContent: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            Text(FormaProductCopy.Onboarding.V2.SavePlan.planSavedOnDeviceTitle)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(FormaProductCopy.Onboarding.V2.SavePlan.localOnlyHint)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                OnboardingWarningBanner(message: errorMessage)
            }

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
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            Text(FormaProductCopy.Onboarding.V2.SavePlan.planSavedOnDeviceTitle)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(FormaProductCopy.Onboarding.V2.SavePlan.signedInSubtitle)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

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
}

#Preview("Signed-out flow") {
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

#Preview("V3 compact signed-out") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        allowsLocalOnlyContinuation: true,
        errorMessage: nil,
        planRecap: OnboardingPreviewData.planRevealState,
        usesCompactLayout: true,
        onContinue: {},
        onContinueWithoutAccount: {},
        onBack: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Signed-in flow") {
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
