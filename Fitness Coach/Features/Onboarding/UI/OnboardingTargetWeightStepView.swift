//
//  OnboardingTargetWeightStepView.swift
//  Fitness Coach
//
//  Forma — target weight step (absolute goal-weight ruler).
//

import SwiftUI

struct OnboardingTargetWeightStepView: View {
    @Binding var formState: OnboardingFormState

    private let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

    @State private var headerVisible = false
    @State private var summaryVisible = false
    @State private var rulerVisible = false
    @State private var guidanceVisible = false
    @State private var isContentPrepared = false

    private var guidanceState: OnboardingTargetWeightGuidanceState? {
        OnboardingTargetWeightGuidanceBuilder.guidanceState(for: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection

            if isContentPrepared, formState.parsedCurrentWeightKg != nil {
                heroSummarySection

                if rulerVisible {
                    targetWeightRuler
                }

                guidanceSection
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
            isContentPrepared = true
            runEntranceAnimation()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressBarSpacing) {
            OnboardingStageProgressHeader(currentStep: .targetWeight)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 6)

            Text(copy.interactionHint)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headerVisible ? 1 : 0)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var heroSummarySection: some View {
        if let headline = OnboardingTargetWeightValues.heroHeadline(for: formState) {
            VStack(spacing: FormaTokens.Spacing.sm) {
                OnboardingTargetWeightHeroSummary(
                    headline: headline,
                    journeyLine: OnboardingTargetWeightValues.currentToTargetSummary(for: formState)
                )

                if let changeLine = OnboardingTargetWeightValues.differenceLabel(for: formState) {
                    Text(changeLine)
                        .font(FormaTokens.Typography.bodyMedium.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: changeLine)
                        .accessibilityLabel(changeLine)
                }
            }
            .opacity(summaryVisible ? 1 : 0)
            .offset(y: summaryVisible ? 0 : 8)
        }
    }

    @ViewBuilder
    private var guidanceSection: some View {
        if let guidanceState {
            OnboardingTargetWeightGuidanceCard(state: guidanceState)
                .opacity(guidanceVisible ? 1 : 0)
                .offset(y: guidanceVisible ? 0 : 8)
        }
    }

    @ViewBuilder
    private var targetWeightRuler: some View {
        OnboardingTargetWeightRulerSelector(formState: $formState)
    }

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.24)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.10)) {
            summaryVisible = true
        }
        withAnimation(.easeOut(duration: 0.32).delay(0.22)) {
            rulerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.42)) {
            guidanceVisible = true
        }
    }
}

#if DEBUG
#Preview("Target Weight — Maintain") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightMaintainFormState)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — Loss") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightLossFormState)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — Gain") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightGainFormState)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Weight — Imperial") {
    OnboardingTargetWeightStepView(
        formState: .constant(OnboardingPreviewData.targetWeightImperialLossFormState)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
