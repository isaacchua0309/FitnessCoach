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

    @State private var headerVisible = false
    @State private var toggleVisible = false
    @State private var pickersVisible = false
    @State private var previewVisible = false
    @State private var suppressSelectionHaptics = true

    private var previewState: OnboardingMaintenancePreviewState {
        OnboardingHeightWeightMaintenanceEstimator.previewState(for: formState)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            headerSection
            pairedPickersSection
            Spacer(minLength: FormaTokens.Spacing.sm)
            previewSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
            runEntranceAnimation()
            DispatchQueue.main.async {
                suppressSelectionHaptics = false
            }
        }
        .onChange(of: formState.heightCmText) { _, _ in
            guard !suppressSelectionHaptics else { return }
            OnboardingHaptics.selectionChanged()
        }
        .onChange(of: formState.currentWeightKgText) { _, _ in
            guard !suppressSelectionHaptics else { return }
            OnboardingHaptics.selectionChanged()
        }
        .onChange(of: formState.unitSystem) { _, _ in
            guard !suppressSelectionHaptics else { return }
            OnboardingHaptics.selectionChanged()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressBarSpacing) {
            OnboardingStageProgressHeader(currentStep: .heightWeight)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 6)

            Text(copy.helper)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headerVisible ? 1 : 0)
                .accessibilityLabel(
                    "\(FormaProductCopy.Onboarding.Flow.Components.helperAccessibilityPrefix). \(copy.helper)"
                )

            unitToggle
                .opacity(toggleVisible ? 1 : 0)
                .offset(y: toggleVisible ? 0 : 4)
        }
        .accessibilityElement(children: .contain)
    }

    private var unitToggle: some View {
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

    @ViewBuilder
    private var pairedPickersSection: some View {
        Group {
            if formState.unitSystem == .metric {
                OnboardingHeightWeightWheelPicker.metric(formState: $formState)
            } else {
                OnboardingHeightWeightWheelPicker.imperial(formState: $formState)
            }
        }
        .opacity(pickersVisible ? 1 : 0)
        .offset(y: pickersVisible ? 0 : 10)
    }

    private var previewSection: some View {
        OnboardingMaintenancePreviewCard(state: previewState)
            .opacity(previewVisible ? 1 : 0)
            .offset(y: previewVisible ? 0 : 8)
    }

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.24)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.10)) {
            toggleVisible = true
        }
        withAnimation(.easeOut(duration: 0.30).delay(0.22)) {
            pickersVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.40)) {
            previewVisible = true
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
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
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
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
