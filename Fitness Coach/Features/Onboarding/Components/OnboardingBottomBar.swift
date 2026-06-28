//
//  OnboardingBottomBar.swift
//  Fitness Coach
//
//  FitPilot AI — Keyboard-safe bottom actions for onboarding.
//

import SwiftUI

struct OnboardingBottomBar: View {
    let currentStep: OnboardingStep
    let isLoading: Bool
    let canContinue: Bool
    var showsRequiredFieldsHint: Bool = false
    var requiredFieldsHint: String? = nil
    var appleHealthPrimaryTitle: String? = nil
    var appleHealthSecondaryTitle: String? = nil
    var isAppleHealthPrimaryEnabled: Bool = true
    var isAppleHealthSkipEnabled: Bool = true
    var onAppleHealthSkip: (() -> Void)? = nil
    let onBack: () -> Void
    let onContinue: () -> Void
    let onComplete: () -> Void
    var onAdjustPlan: (() -> Void)? = nil
    var saveTrustNote: String? = nil
    var canExitToWelcome: Bool = false
    var onExitToWelcome: (() -> Void)? = nil
    var flowFloor: OnboardingStep = .introProof

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var resolvedButtonHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    private var showsBackButton: Bool {
        showsWelcomeExitBackButton
            || currentStep.allowsBackNavigation(in: OnboardingStep.flow, notBefore: flowFloor)
    }

    private var showsWelcomeExitBackButton: Bool {
        canExitToWelcome && onExitToWelcome != nil
    }

    private var showsAdjustPlan: Bool {
        currentStep == .planReveal && onAdjustPlan != nil
    }

    private var primaryTitle: String {
        switch currentStep {
        case .review:
            return FormaProductCopy.Onboarding.Flow.Summary.buildPlanCTA
        case .planReveal:
            return FormaProductCopy.Onboarding.Flow.PlanReveal.savePlanCTA
        case .targetEncouragement:
            return FormaProductCopy.Onboarding.Flow.TargetEncouragement.continueCTA
        case .almostThere:
            return FormaProductCopy.Onboarding.Flow.AlmostThere.continueCTA
        case .introProof:
            return FormaProductCopy.Onboarding.Flow.IntroProof.continueCTA
        case .formaProof:
            return FormaProductCopy.Onboarding.Flow.FormaProof.continueCTA
        case .appleHealth:
            return appleHealthPrimaryTitle ?? FormaProductCopy.Onboarding.Flow.AppleHealth.connectCTA
        default:
            return FormaProductCopy.Common.continueAction
        }
    }

    private var isPrimaryActionEnabled: Bool {
        if currentStep == .appleHealth {
            return isAppleHealthPrimaryEnabled
        }
        return canContinue
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.footerInnerSpacing) {
            HStack(spacing: FormaTokens.Spacing.md) {
                if showsBackButton {
                    Button {
                        if showsWelcomeExitBackButton, let onExitToWelcome {
                            onExitToWelcome()
                        } else {
                            onBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .frame(width: resolvedButtonHeight, height: resolvedButtonHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityLabel(FormaProductCopy.Common.back)
                }

                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        if isLoading {
                            SwiftUI.ProgressView()
                                .tint(OnboardingTheme.ctaText)
                        }
                        Text(primaryTitle)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(isPrimaryActionEnabled && !isLoading ? OnboardingTheme.ctaText : OnboardingTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: resolvedButtonHeight)
                    .background(primaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || (currentStep == .appleHealth ? !isAppleHealthPrimaryEnabled : false))
                .accessibilityLabel(primaryTitle)
                .accessibilityHint(canContinue ? "" : resolvedRequiredFieldsHint)
            }

            if currentStep == .appleHealth,
               let appleHealthSecondaryTitle,
               let onAppleHealthSkip {
                Button(action: onAppleHealthSkip) {
                    Text(appleHealthSecondaryTitle)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(
                            isAppleHealthSkipEnabled && !isLoading
                                ? OnboardingTheme.secondaryText
                                : OnboardingTheme.tertiaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: resolvedButtonHeight)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !isAppleHealthSkipEnabled)
                .accessibilityLabel(appleHealthSecondaryTitle)
            }

            if let saveTrustNote, showsAdjustPlan {
                Text(saveTrustNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(saveTrustNote)
            }

            if showsAdjustPlan, let onAdjustPlan {
                Button(action: onAdjustPlan) {
                    Text(FormaProductCopy.Onboarding.V2.PlanReveal.adjustPlanCTA)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .frame(height: resolvedButtonHeight)
                        .background(footerSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.PlanReveal.adjustPlanCTA)
            }

            if showsRequiredFieldsHint, !canContinue, !isLoading {
                Text(resolvedRequiredFieldsHint)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(resolvedRequiredFieldsHint)
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.footerVerticalPadding)
        .padding(.bottom, OnboardingLayout.footerVerticalPadding)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        OnboardingTheme.background.opacity(0),
                        OnboardingTheme.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 14)

                OnboardingTheme.background
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(OnboardingTheme.border.opacity(0.3))
                .frame(height: 0.5)
        }
        .onboardingMeasureFooterHeight()
    }

    private var resolvedRequiredFieldsHint: String {
        requiredFieldsHint ?? FormaProductCopy.Common.completeRequiredFields
    }

    private var primaryBackground: some View {
        Group {
            if isPrimaryActionEnabled && !isLoading {
                OnboardingTheme.ctaBackground
            } else {
                OnboardingTheme.cardElevated
            }
        }
    }

    private var footerSecondaryBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
            .fill(OnboardingTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .stroke(OnboardingTheme.border, lineWidth: 1)
            )
    }
}

#Preview("Continue disabled") {
    OnboardingBottomBar(
        currentStep: .heightWeight,
        isLoading: false,
        canContinue: false,
        showsRequiredFieldsHint: true,
        onBack: {},
        onContinue: {},
        onComplete: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Plan reveal") {
    OnboardingBottomBar(
        currentStep: .planReveal,
        isLoading: false,
        canContinue: true,
        onBack: {},
        onContinue: {},
        onComplete: {},
        onAdjustPlan: {},
        saveTrustNote: FormaProductCopy.Onboarding.Flow.PlanReveal.signedOutSaveTrustNote
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
