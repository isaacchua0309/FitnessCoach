//
//  OnboardingTargetWeightRulerSelector.swift
//  Fitness Coach
//
//  Forma — Target-weight horizontal ruler (SwiftHorizontalRuler adapter).
//

import SwiftHorizontalRuler
import SwiftUI
import UIKit

/// Absolute target-weight ruler for onboarding. Persists canonical kg via `OnboardingFormState`.
struct OnboardingTargetWeightRulerSelector: View {
    @Binding var formState: OnboardingFormState

    private let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

    @State private var lastHapticDisplayValue: Double?

    var body: some View {
        if let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(from: formState),
           formState.parsedCurrentWeightKg != nil {
            HorizontalRuler(
                value: displayBinding,
                config: rulerConfig(for: range)
            )
            .frame(height: OnboardingLayout.heroRulerHeight)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(copy.rulerAccessibilityLabel)
            .accessibilityValue(accessibilityAnnouncement)
            .accessibilityHint(copy.interactionHint)
            .id(OnboardingTargetWeightValues.rulerIdentity(for: formState))
            .onAppear {
                lastHapticDisplayValue = OnboardingTargetWeightValues.resolvedRulerDisplayValue(from: formState)
            }
            .onChange(of: displayValue) { previous, next in
                guard lastHapticDisplayValue != nil else {
                    lastHapticDisplayValue = next
                    return
                }
                guard previous != next else { return }
                OnboardingHaptics.selectionChanged()
                lastHapticDisplayValue = next
            }
        }
    }

    // MARK: - Binding (display units → canonical kg)

    private var displayValue: Double {
        OnboardingTargetWeightValues.resolvedRulerDisplayValue(from: formState)
    }

    private var displayBinding: Binding<Double> {
        Binding(
            get: { displayValue },
            set: { newDisplay in
                OnboardingTargetWeightValues.setGoalFromDisplay(newDisplay, in: &formState)
            }
        )
    }

    // MARK: - SwiftHorizontalRuler config

    private func rulerConfig(for range: ClosedRange<Double>) -> HorizontalRulerConfig {
        let unitSystem = formState.unitSystem
        let minorStep = OnboardingTargetWeightValues.rulerStep(for: unitSystem)
        let majorStep = majorIncrement(for: unitSystem)

        return HorizontalRulerConfig(
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            minorIncrement: minorStep,
            majorIncrement: majorStep,
            tickSpacing: OnboardingLayout.heroRulerTickSpacing,
            indicatorColor: OnboardingTargetWeightRulerUIKitBridge.indicatorColor,
            hapticStyle: .none,
            tickSound: false,
            labelFormatter: OnboardingTargetWeightValues.targetWeightTickFormatter
        )
    }

    private func majorIncrement(for unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return 1.0
        case .imperial:
            return 1.0
        }
    }

    // MARK: - Accessibility

    private var accessibilityAnnouncement: String {
        guard let goalKg = OnboardingTargetWeightValues.resolvedGoalKg(from: formState) else {
            return copy.rulerAccessibilityLabel
        }

        let targetLabel = OnboardingTargetWeightValues.targetWeightLabel(
            valueKg: goalKg,
            unitSystem: formState.unitSystem
        )
        let journey = OnboardingTargetWeightValues.currentToTargetSummary(for: formState)
        let delta = OnboardingTargetWeightValues.differenceLabel(for: formState)

        return [targetLabel, journey, delta]
            .compactMap { $0 }
            .joined(separator: ". ")
    }
}

// MARK: - UIKit bridge

private enum OnboardingTargetWeightRulerUIKitBridge {
    @MainActor
    static var indicatorColor: UIColor {
        UIColor(OnboardingTheme.progress)
    }
}

#if DEBUG
#Preview("Target weight ruler — maintain") {
    OnboardingTargetWeightRulerSelector(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setHeightCm(170, in: &state)
            OnboardingHeightWeightValues.setWeightKg(90, in: &state)
            state.unitSystem = .metric
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
            return state
        }())
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target weight ruler — loss") {
    OnboardingTargetWeightRulerSelector(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setHeightCm(170, in: &state)
            OnboardingHeightWeightValues.setWeightKg(90, in: &state)
            state.unitSystem = .metric
            OnboardingTargetWeightValues.setGoalWeightKg(85.3, in: &state)
            return state
        }())
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Target weight ruler — imperial") {
    OnboardingTargetWeightRulerSelector(
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
    .formaThemePreview()
}
#endif
