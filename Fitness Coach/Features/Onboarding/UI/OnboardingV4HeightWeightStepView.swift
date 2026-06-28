//
//  OnboardingV4HeightWeightStepView.swift
//  Fitness Coach
//
//  Forma — V4 height and current weight capture (metric or imperial).
//

import SwiftUI

struct OnboardingV4HeightWeightStepView: View {
    @Binding var formState: OnboardingFormState

    private let copy = FormaProductCopy.Onboarding.V4.HeightWeight.self

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            Text(copy.helper)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "\(FormaProductCopy.Onboarding.V4.Components.helperAccessibilityPrefix). \(copy.helper)"
                )

            unitToggle

            measurementPickers
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        }
    }

    private var unitToggle: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            Picker(
                FormaProductCopy.Onboarding.V2.Body.unitSectionTitle,
                selection: $formState.unitSystem
            ) {
                Text(FormaProductCopy.Onboarding.V2.Body.unitMetricLabel).tag(UnitSystem.metric)
                Text(FormaProductCopy.Onboarding.V2.Body.unitImperialLabel).tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.unitSectionTitle)
        }
    }

    @ViewBuilder
    private var measurementPickers: some View {
        if formState.unitSystem == .metric {
            OnboardingV4HeightWeightWheelPicker.metric(formState: $formState)
        } else {
            OnboardingV4HeightWeightWheelPicker.imperial(formState: $formState)
        }
    }
}

#if DEBUG
#Preview("V4 Height & Weight — Metric") {
    OnboardingV4HeightWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)
            state.unitSystem = .metric
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}

#Preview("V4 Height & Weight — Imperial") {
    OnboardingV4HeightWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)
            state.unitSystem = .imperial
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}
#endif
