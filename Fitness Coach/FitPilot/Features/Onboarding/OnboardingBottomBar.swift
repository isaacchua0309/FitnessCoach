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

    private var primaryTitle: String {
        switch currentStep {
        case .preferences:
            return "Generate Plan"
        case .planPreview:
            return "Start FitPilot"
        default:
            return "Continue"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if currentStep != .welcome {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: currentStep == .planPreview ? 130 : 112)
                    }
                    .buttonStyle(.bordered)
                    .tint(OnboardingTheme.secondaryText)
                    .disabled(isLoading)
                    .accessibilityLabel("Back")
                }

                Button(action: currentStep == .planPreview ? onComplete : onContinue) {
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

            if !canContinue, !isLoading {
                Text("Complete the required fields to continue.")
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Complete the required fields to continue.")
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
