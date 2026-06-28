//
//  OnboardingHeightWeightStepView.swift
//  Fitness Coach
//
//  Forma — height and current weight capture (metric or imperial).
//

import SwiftUI

struct OnboardingHeightWeightStepView: View {
    @Binding var formState: OnboardingFormState

    private let copy = FormaProductCopy.Onboarding.Flow.HeightWeight.self

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            Text(copy.helper)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "\(FormaProductCopy.Onboarding.Flow.Components.helperAccessibilityPrefix). \(copy.helper)"
                )

            unitToggle

            measurementPickers
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
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
            OnboardingHeightWeightWheelPicker.metric(formState: $formState)
        } else {
            OnboardingHeightWeightWheelPicker.imperial(formState: $formState)
        }
    }
}

#if DEBUG
#Preview("Height & Weight — Metric") {
    OnboardingHeightWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
            state.unitSystem = .metric
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}

#Preview("Height & Weight — Imperial") {
    OnboardingHeightWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
            state.unitSystem = .imperial
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}
#endif
