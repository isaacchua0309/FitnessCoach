//
//  OnboardingTargetWeightStepView.swift
//  Fitness Coach
//
//  Forma — target weight via horizontal loss ruler.
//

import SwiftUI

struct OnboardingTargetWeightStepView: View {
    @Binding var formState: OnboardingFormState

    private var showsGoalBMITooLowWarning: Bool {
        guard let goal = OnboardingTargetWeightValues.resolvedGoalKg(from: formState),
              let height = formState.parsedHeightCm else {
            return false
        }
        return OnboardingGoalProjectionBuilder.isGoalBMITooLow(
            goalWeightKg: goal,
            heightCm: height
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if showsGoalBMITooLowWarning {
                OnboardingWarningBanner(message: FormaProductCopy.Onboarding.V2.Goal.bmiWarning)
            }

            if formState.parsedCurrentWeightKg != nil {
                lossRuler

                if let summary = OnboardingTargetWeightValues.currentToTargetSummary(for: formState) {
                    Text(summary)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(summary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        }
    }

    @ViewBuilder
    private var lossRuler: some View {
        let centerLabel = OnboardingTargetWeightValues.targetWeightCenterLabel(for: formState)
        let accessibilityTarget = centerLabel

        if formState.unitSystem == .metric {
            if let current = formState.parsedCurrentWeightKg {
                let range = OnboardingTargetWeightValues.lossRangeDisplay(
                    currentWeightKg: current,
                    heightCm: formState.parsedHeightCm,
                    unitSystem: .metric
                )
                OnboardingRulerPickerFactory.weightLossKg(
                    value: lossDisplayBinding,
                    range: range,
                    centerDisplayText: centerLabel,
                    accessibilityValueText: accessibilityTarget
                )
                .accessibilityLabel(FormaProductCopy.Onboarding.Flow.TargetWeight.lossRulerAccessibilityLabel)
            }
        } else if let current = formState.parsedCurrentWeightKg {
            let range = OnboardingTargetWeightValues.lossRangeDisplay(
                currentWeightKg: current,
                heightCm: formState.parsedHeightCm,
                unitSystem: .imperial
            )
            OnboardingRulerPickerFactory.weightLossLb(
                value: lossDisplayBinding,
                range: range,
                centerDisplayText: centerLabel,
                accessibilityValueText: accessibilityTarget
            )
            .accessibilityLabel(FormaProductCopy.Onboarding.Flow.TargetWeight.lossRulerAccessibilityLabel)
        }
    }

    private var lossDisplayBinding: Binding<Double> {
        Binding(
            get: {
                OnboardingTargetWeightValues.resolvedLossDisplay(from: formState)
            },
            set: { newValue in
                OnboardingTargetWeightValues.setGoalFromLossDisplay(newValue, in: &formState)
            }
        )
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
    .padding()
    .background(OnboardingTheme.background)
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
    .padding()
    .background(OnboardingTheme.background)
}
#endif
