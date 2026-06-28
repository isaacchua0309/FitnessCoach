//
//  OnboardingTargetWeightStepView.swift
//  Fitness Coach
//
//  Forma — target weight via horizontal loss ruler.
//

import SwiftUI

struct OnboardingTargetWeightStepView: View {
    @Binding var formState: OnboardingFormState

    private let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

    @State private var headerVisible = false
    @State private var summaryVisible = false
    @State private var rulerVisible = false
    @State private var guidanceVisible = false

    private var guidanceState: OnboardingTargetWeightGuidanceState? {
        OnboardingTargetWeightGuidanceBuilder.guidanceState(for: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection

            if formState.parsedCurrentWeightKg != nil {
                heroSummarySection
                rulerSection
                guidanceSection
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
            runEntranceAnimation()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressBarSpacing) {
            OnboardingStageProgressHeader(currentStep: .targetWeight)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 6)

            Text(copy.lossRulerHint)
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
            OnboardingTargetWeightHeroSummary(
                headline: headline,
                journeyLine: OnboardingTargetWeightValues.currentToTargetSummary(for: formState)
            )
            .opacity(summaryVisible ? 1 : 0)
            .offset(y: summaryVisible ? 0 : 8)
        }
    }

    @ViewBuilder
    private var rulerSection: some View {
        lossRuler
            .opacity(rulerVisible ? 1 : 0)
            .offset(y: rulerVisible ? 0 : 12)
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
    private var lossRuler: some View {
        let centerLabel = OnboardingTargetWeightValues.rulerCenterLabel(for: formState)
        let accessibilityTarget = OnboardingTargetWeightValues.currentToTargetSummary(for: formState)
            ?? centerLabel
            ?? copy.lossRulerAccessibilityLabel

        if formState.unitSystem == .metric {
            if let current = formState.parsedCurrentWeightKg {
                let range = OnboardingTargetWeightValues.deltaRangeDisplay(
                    currentWeightKg: current,
                    heightCm: formState.parsedHeightCm,
                    unitSystem: .metric
                )
                OnboardingRulerPickerFactory.weightDeltaKg(
                    value: deltaDisplayBinding,
                    range: range,
                    presentation: .hero,
                    centerDisplayText: centerLabel,
                    accessibilityValueText: accessibilityTarget
                )
                .accessibilityLabel(copy.lossRulerAccessibilityLabel)
            }
        } else if let current = formState.parsedCurrentWeightKg {
            let range = OnboardingTargetWeightValues.deltaRangeDisplay(
                currentWeightKg: current,
                heightCm: formState.parsedHeightCm,
                unitSystem: .imperial
            )
            OnboardingRulerPickerFactory.weightDeltaLb(
                value: deltaDisplayBinding,
                range: range,
                presentation: .hero,
                centerDisplayText: centerLabel,
                accessibilityValueText: accessibilityTarget
            )
            .accessibilityLabel(copy.lossRulerAccessibilityLabel)
        }
    }

    private var deltaDisplayBinding: Binding<Double> {
        Binding(
            get: {
                OnboardingTargetWeightValues.resolvedDeltaDisplay(from: formState)
            },
            set: { newValue in
                OnboardingTargetWeightValues.setGoalFromDeltaDisplay(newValue, in: &formState)
            }
        )
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
#Preview("Target Weight — Metric") {
    OnboardingTargetWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setHeightCm(170, in: &state)
            OnboardingHeightWeightValues.setWeightKg(72, in: &state)
            state.unitSystem = .metric
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
            return state
        }())
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Target Weight — Imperial") {
    OnboardingTargetWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setHeightCm(170, in: &state)
            OnboardingHeightWeightValues.setWeightKg(72, in: &state)
            state.unitSystem = .imperial
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
            return state
        }())
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
