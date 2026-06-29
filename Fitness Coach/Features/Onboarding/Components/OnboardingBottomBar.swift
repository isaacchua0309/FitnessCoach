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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48
    @State private var planRevealCTAPulse = false
    @State private var planRevealPulseTask: Task<Void, Never>?

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

    private var showsBuildPlanAnticipation: Bool {
        currentStep == .review
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.footerInnerSpacing) {
            if let saveTrustNote, showsAdjustPlan {
                Text(saveTrustNote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(saveTrustNote)
            }

            if showsBuildPlanAnticipation {
                VStack(spacing: 2) {
                    Text(FormaProductCopy.Onboarding.Flow.Summary.buildPlanAnticipationHeadline)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text(FormaProductCopy.Onboarding.Flow.Summary.buildPlanAnticipationSubline)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, OnboardingLayout.buildPlanAnticipationTopPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    FormaProductCopy.Onboarding.Flow.Summary.buildPlanAnticipationAccessibilityLabel
                )
            }

            HStack(spacing: FormaTokens.Spacing.md) {
                if showsBackButton {
                    Button {
                        OnboardingHaptics.selectionChanged()
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

                OnboardingPrimaryCTA(
                    title: primaryTitle,
                    variant: currentStep == .review ? .launch : .standard,
                    isEnabled: currentStep == .appleHealth ? isAppleHealthPrimaryEnabled : isPrimaryActionEnabled,
                    isLoading: isLoading,
                    accessibilityHint: canContinue ? "" : resolvedRequiredFieldsHint,
                    action: onContinue
                )
                .scaleEffect(planRevealCTAScale)
                .animation(
                    reduceMotion ? nil : OnboardingMotion.revealCTAPulse,
                    value: planRevealCTAPulse
                )
            }

            if showsAdjustPlan, let onAdjustPlan {
                Button {
                    OnboardingHaptics.primaryActionTapped()
                    onAdjustPlan()
                } label: {
                    Text(FormaProductCopy.Onboarding.V2.PlanReveal.adjustPlanCTA)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(
                            isLoading ? OnboardingTheme.tertiaryText : OnboardingTheme.secondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.PlanReveal.adjustPlanCTA)
            }

            if currentStep == .appleHealth,
               let appleHealthSecondaryTitle,
               let onAppleHealthSkip {
                Button {
                    OnboardingHaptics.primaryActionTapped()
                    onAppleHealthSkip()
                } label: {
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
        .padding(.top, resolvedFooterTopPadding)
        .padding(.bottom, OnboardingLayout.footerVerticalPadding)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                OnboardingGradients.footerFade
                    .frame(height: 14)

                OnboardingTheme.background
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(OnboardingTheme.border.opacity(reviewFooterHairlineOpacity))
                .frame(height: 0.5)
        }
        .onboardingMeasureFooterHeight()
        .onAppear {
            guard currentStep == .planReveal else { return }
            schedulePlanRevealCTAPulse()
        }
        .onChange(of: currentStep) { _, step in
            planRevealPulseTask?.cancel()
            planRevealCTAPulse = false
            guard step == .planReveal else { return }
            schedulePlanRevealCTAPulse()
        }
    }

    private var planRevealCTAScale: CGFloat {
        currentStep == .planReveal && planRevealCTAPulse ? 1.02 : 1
    }

    private func schedulePlanRevealCTAPulse() {
        guard !reduceMotion else { return }
        planRevealPulseTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(OnboardingPlanRevealTiming.ctaPulse * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            planRevealCTAPulse = true
            try? await Task.sleep(
                nanoseconds: UInt64(OnboardingPlanRevealTiming.ctaPulseDuration * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            planRevealCTAPulse = false
        }
    }

    private var resolvedRequiredFieldsHint: String {
        requiredFieldsHint ?? FormaProductCopy.Common.completeRequiredFields
    }

    private var resolvedFooterTopPadding: CGFloat {
        currentStep == .review ? OnboardingLayout.reviewFooterTopPadding : OnboardingLayout.footerVerticalPadding
    }

    private var reviewFooterHairlineOpacity: Double {
        currentStep == .review ? 0.15 : 0.3
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
