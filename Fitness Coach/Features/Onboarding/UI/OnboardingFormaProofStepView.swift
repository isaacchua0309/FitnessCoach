//
//  OnboardingFormaProofStepView.swift
//  Fitness Coach
//
//  Forma — goal-aware proof screen before plan review.
//

import SwiftUI

struct OnboardingFormaProofStepView: View {
    let formState: OnboardingFormState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headerVisible = false
    @State private var heroVisible = false
    @State private var comparisonVisible = false
    @State private var pathVisible = false
    @State private var trustVisible = false
    @State private var didPlayAppearHaptic = false

    private var displayState: OnboardingFormaProofState {
        OnboardingFormaProofBuilder.build(from: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection
            titleSection
            heroSection
            comparisonSection
            pathSection
            trustSection
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayState.accessibilityLabel)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .formaProof)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
            Text(displayState.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(displayState.subtitle)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 4)
    }

    private var heroSection: some View {
        OnboardingFormaProofHeroCard(
            heroMetric: displayState.heroMetric,
            journeyLine: displayState.journeyLine,
            supportingCopy: displayState.heroSupporting
        )
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 8)
        .scaleEffect(heroVisible ? 1 : 0.97)
    }

    private var comparisonSection: some View {
        OnboardingFormaProofStructuredComparisonCard(state: displayState.comparison)
            .opacity(comparisonVisible ? 1 : 0)
            .offset(y: comparisonVisible ? 0 : 8)
    }

    private var pathSection: some View {
        OnboardingFormaProofPathVisual(
            style: displayState.pathStyle,
            animatePlannedPath: pathVisible
        )
        .opacity(pathVisible ? 1 : 0)
        .offset(y: pathVisible ? 0 : 6)
    }

    private var trustSection: some View {
        OnboardingAlmostThereTrustStrip(copy: displayState.trustStrip)
            .opacity(trustVisible ? 1 : 0)
            .offset(y: trustVisible ? 0 : 8)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            heroVisible = true
            comparisonVisible = true
            pathVisible = true
            trustVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.10)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.26)) {
            comparisonVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.40)) {
            pathVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.54)) {
            trustVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Forma Proof — Loss") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Gain") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(66, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(4, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Maintain") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromLossKg(0, in: &state)
            return state
        }()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Fallback") {
    OnboardingFormaProofStepView(formState: OnboardingFormState())
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Forma Proof — Imperial") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            state.unitSystem = .imperial
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
            return state
        }()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
