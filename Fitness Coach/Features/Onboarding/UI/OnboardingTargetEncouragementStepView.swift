//
//  OnboardingTargetEncouragementStepView.swift
//  Fitness Coach
//
//  Forma — goal confirmation after target weight selection.
//

import SwiftUI

struct OnboardingTargetEncouragementStepView: View {
    let formState: OnboardingFormState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var heroVisible = false
    @State private var journeyVisible = false
    @State private var reassuranceVisible = false
    @State private var benefitsVisible = false
    @State private var didPlayAppearHaptic = false

    private var displayState: OnboardingTargetEncouragementState {
        OnboardingTargetEncouragementCopyBuilder.build(from: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
            headerSection
            heroSection
            reassuranceSection
            benefitsSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .targetEncouragement)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
    }

    private var heroSection: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            OnboardingMetricHighlight(value: displayState.heroMetric)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .scaleEffect(heroVisible ? 1 : 0.94)
                .opacity(heroVisible ? 1 : 0)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: displayState.heroMetric)

            if let journeyLine = displayState.journeyLine {
                Text(journeyLine)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .opacity(journeyVisible ? 1 : 0)
                    .offset(y: journeyVisible ? 0 : 6)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: journeyLine)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayState.accessibilityLabel)
    }

    private var reassuranceSection: some View {
        OnboardingTargetEncouragementReassuranceCard(
            title: displayState.reassuranceTitle,
            bodyCopy: displayState.reassuranceBody
        )
        .opacity(reassuranceVisible ? 1 : 0)
        .offset(y: reassuranceVisible ? 0 : 8)
    }

    private var benefitsSection: some View {
        OnboardingTargetEncouragementBenefitsSection(benefits: displayState.benefits)
            .opacity(benefitsVisible ? 1 : 0)
            .offset(y: benefitsVisible ? 0 : 8)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            heroVisible = true
            journeyVisible = true
            reassuranceVisible = true
            benefitsVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.10)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.24)) {
            journeyVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.38)) {
            reassuranceVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.52)) {
            benefitsVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Target Encouragement — Loss") {
    OnboardingTargetEncouragementStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Encouragement — Maintain") {
    OnboardingTargetEncouragementStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(72, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &state)
            return state
        }()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target Encouragement — Fallback") {
    OnboardingTargetEncouragementStepView(formState: OnboardingFormState())
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
