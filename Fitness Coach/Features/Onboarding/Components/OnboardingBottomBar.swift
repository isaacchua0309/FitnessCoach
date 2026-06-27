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
    let onBack: () -> Void
    let onContinue: () -> Void
    let onComplete: () -> Void
    var onAdjustPlan: (() -> Void)? = nil

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var showsBackButton: Bool {
        currentStep.allowsBackNavigation(isV2Enabled: isV2)
    }

    private var usesCompleteAction: Bool {
        currentStep == .planPreview && !isV2
    }

    private var primaryTitle: String {
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
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if showsBackButton {
                    Button(action: onBack) {
                        Label(FormaProductCopy.Common.back, systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: usesCompleteAction ? 130 : 112)
                    }
                    .buttonStyle(.bordered)
                    .tint(OnboardingTheme.secondaryText)
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
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(OnboardingTheme.accent)
                .disabled(isLoading || !canContinue)
                .accessibilityLabel(primaryTitle)
            }

            if currentStep == .planReveal, let onAdjustPlan {
                Button(action: onAdjustPlan) {
                    Text(FormaProductCopy.Onboarding.V2.PlanReveal.adjustPlanCTA)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(OnboardingTheme.secondaryText)
                .disabled(isLoading)
                .accessibilityLabel(FormaProductCopy.Onboarding.V2.PlanReveal.adjustPlanCTA)
            }

            if !canContinue, !isLoading {
                Text(FormaProductCopy.Common.completeRequiredFields)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(FormaProductCopy.Common.completeRequiredFields)
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
