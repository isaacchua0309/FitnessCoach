//
//  OnboardingBottomBar.swift
//  Fitness Coach
//
//  FitPilot AI — Keyboard-safe bottom actions for onboarding.
//

import SwiftUI

struct OnboardingBottomBar: View {
    let currentStep: OnboardingStep
    var currentV3Step: OnboardingV3Step?
    let isLoading: Bool
    let canContinue: Bool
    var showsRequiredFieldsHint: Bool = false
    let onBack: () -> Void
    let onContinue: () -> Void
    let onComplete: () -> Void
    var onAdjustPlan: (() -> Void)? = nil
    var saveTrustNote: String? = nil

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }
    private var usesV3: Bool { currentV3Step != nil }

    private var resolvedButtonHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    private var showsBackButton: Bool {
        if let currentV3Step {
            return currentV3Step.allowsBackNavigation(in: OnboardingV3Step.flowForActiveScope())
        }
        return currentStep.allowsBackNavigation(isV2Enabled: OnboardingStepPolicy.isV2Enabled)
    }

    private var usesCompleteAction: Bool {
        currentStep == .planPreview && !isV2
    }

    private var showsAdjustPlan: Bool {
        (currentV3Step == .planReveal || currentStep == .planReveal) && onAdjustPlan != nil
    }

    private var primaryTitle: String {
        if let currentV3Step {
            switch currentV3Step {
            case .review:
                return FormaProductCopy.Onboarding.V2.Summary.buildPlanCTA
            case .planReveal:
                return FormaProductCopy.Onboarding.V2.PlanReveal.savePlanCTA
            default:
                return FormaProductCopy.Common.continueAction
            }
        }

        switch currentStep {
        case .landing:
            return FormaProductCopy.Onboarding.V2.Landing.cta
        case .preferences where !isV2:
            return "Generate Plan"
        case .summary:
            return FormaProductCopy.Onboarding.V2.Summary.buildPlanCTA
        case .planReveal:
            return FormaProductCopy.Onboarding.V2.PlanReveal.savePlanCTA
        case .planPreview:
            return FormaProductCopy.Onboarding.startButton
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

                Button(action: usesCompleteAction ? onComplete : onContinue) {
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
        currentStep: .body,
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

#Preview("Continue enabled") {
    OnboardingBottomBar(
        currentStep: .body,
        isLoading: false,
        canContinue: true,
        showsRequiredFieldsHint: false,
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
        saveTrustNote: FormaProductCopy.Onboarding.V2.PlanReveal.signedOutSaveTrustNote
    )
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Plan reveal signed in") {
    OnboardingBottomBar(
        currentStep: .planReveal,
        isLoading: false,
        canContinue: true,
        onBack: {},
        onContinue: {},
        onComplete: {},
        onAdjustPlan: {},
        saveTrustNote: FormaProductCopy.Onboarding.V2.PlanReveal.signedInSaveTrustNote
    )
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    OnboardingBottomBar(
        currentStep: .goal,
        isLoading: false,
        canContinue: true,
        onBack: {},
        onContinue: {},
        onComplete: {}
    )
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
