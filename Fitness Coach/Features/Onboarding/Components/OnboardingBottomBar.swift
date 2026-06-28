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
    let onBack: () -> Void
    let onContinue: () -> Void
    let onComplete: () -> Void
    var onAdjustPlan: (() -> Void)? = nil
    var saveTrustNote: String? = nil
    var flowFloor: OnboardingStep = .introProof

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var resolvedButtonHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    private var showsBackButton: Bool {
        currentStep.allowsBackNavigation(in: OnboardingStep.flow, notBefore: flowFloor)
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
        case .formaProof:
            return FormaProductCopy.Onboarding.Flow.FormaProof.continueCTA
        default:
            return FormaProductCopy.Common.continueAction
        }
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.footerInnerSpacing) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                if showsBackButton {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: resolvedButtonHeight, height: resolvedButtonHeight)
                            .background(footerSecondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .accessibilityLabel(FormaProductCopy.Common.back)
                }

                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        if isLoading {
                            SwiftUI.ProgressView()
                                .tint(.white)
                        }
                        Text(primaryTitle)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(canContinue && !isLoading ? FormaTokens.Color.textPrimary : OnboardingTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: resolvedButtonHeight)
                    .background(primaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading || !canContinue)
                .accessibilityLabel(primaryTitle)
                .accessibilityHint(canContinue ? "" : FormaProductCopy.Common.completeRequiredFields)
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
                Text(FormaProductCopy.Common.completeRequiredFields)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(FormaProductCopy.Common.completeRequiredFields)
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.footerVerticalPadding)
        .padding(.bottom, OnboardingLayout.footerVerticalPadding)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .onboardingMeasureFooterHeight()
    }

    private var primaryBackground: some View {
        Group {
            if canContinue && !isLoading {
                OnboardingTheme.accent
            } else {
                FormaTokens.Color.surfaceElevated
            }
        }
    }

    private var footerSecondaryBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
            .fill(FormaTokens.Color.surface)
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
    .preferredColorScheme(.dark)
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
    .preferredColorScheme(.dark)
}
