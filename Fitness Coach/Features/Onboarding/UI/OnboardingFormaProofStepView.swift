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
    @State private var titleVisible = false
    @State private var heroVisible = false
    @State private var comparisonVisible = false
    @State private var trustVisible = false
    @State private var didPlayAppearHaptic = false

    private var displayState: OnboardingFormaProofState {
        OnboardingFormaProofBuilder.build(from: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            headerSection
            titleSection
            heroSection
            comparisonSection
            trustSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayState.accessibilityLabel)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    private var headerSection: some View {
        OnboardingStageProgressHeader(currentStep: .formaProof, showsTitles: false)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 6)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(displayState.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(displayState.subtitle)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(titleVisible ? 1 : 0)
        .offset(y: titleVisible ? 0 : 4)
    }

    private var heroSection: some View {
        OnboardingFormaProofHeroCard(
            heroMetric: displayState.heroMetric,
            journeyLine: displayState.journeyLine,
            supportingCopy: displayState.heroSupporting
        )
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 6)
        .scaleEffect(heroVisible ? 1 : 0.98)
    }

    private var comparisonSection: some View {
        OnboardingFormaProofStructuredComparisonCard(state: displayState.comparison)
            .opacity(comparisonVisible ? 1 : 0)
            .offset(y: comparisonVisible ? 0 : 6)
    }

    private var trustSection: some View {
        Text(displayState.trustStrip)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(displayState.trustStrip)
            .opacity(trustVisible ? 1 : 0)
            .offset(y: trustVisible ? 0 : 4)
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            titleVisible = true
            heroVisible = true
            comparisonVisible = true
            trustVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.06)) {
            titleVisible = true
        }
        withAnimation(.easeOut(duration: 0.26).delay(0.12)) {
            heroVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.24)) {
            comparisonVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.36)) {
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
            OnboardingHeightWeightValues.setWeightKg(90, in: &state)
            OnboardingTargetWeightValues.setGoalFromLossKg(15, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Gain") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(8, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
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
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Fallback") {
    OnboardingFormaProofStepView(formState: OnboardingFormState())
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Forma Proof — Small iPhone") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Forma Proof — Large Dynamic Type") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
#endif
