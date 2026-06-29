//
//  OnboardingTargetWeightRulerSelector.swift
//  Fitness Coach
//
//  Forma — Target-weight horizontal ruler (PremiumWeightRulerView adapter).
//

import SwiftUI

/// Onboarding adapter: binds `OnboardingFormState` goal weight to `PremiumWeightRulerView`.
struct OnboardingTargetWeightRulerSelector: View {
    @Binding var formState: OnboardingFormState
    var rulerHeight: CGFloat = OnboardingLayout.premiumRulerHeight

    private let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

    @State private var lastTrackedGoalKg: Double?
    @State private var hapticBoundaryMarks = OnboardingTargetWeightRulerHaptics.BoundaryMarks()

    var body: some View {
        if let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(from: formState),
           formState.parsedCurrentWeightKg != nil {
            PremiumWeightRulerView(
                value: displayBinding,
                config: PremiumWeightRulerView.makeConfig(
                    range: range,
                    unitSystem: formState.unitSystem
                ),
                height: rulerHeight,
                accessibilityLabel: copy.rulerAccessibilityLabel,
                accessibilityValue: accessibilityAnnouncement,
                accessibilityHint: copy.interactionHint
            )
            .id(OnboardingTargetWeightValues.selectorIdentity(for: formState))
            .onAppear {
                seedHapticBoundaryTracking()
            }
            .onChange(of: displayValue) { _, _ in
                emitBoundaryHapticIfNeeded()
            }
        }
    }

    private func seedHapticBoundaryTracking() {
        guard let kg = formState.parsedGoalWeightKg else {
            lastTrackedGoalKg = nil
            hapticBoundaryMarks = .init()
            return
        }
        lastTrackedGoalKg = kg
        hapticBoundaryMarks = OnboardingTargetWeightRulerHaptics.BoundaryMarks(
            oneKg: OnboardingTargetWeightRulerHaptics.oneKgMark(for: kg),
            fiveKg: OnboardingTargetWeightRulerHaptics.fiveKgMark(for: kg)
        )
    }

    private func emitBoundaryHapticIfNeeded() {
        guard let kg = formState.parsedGoalWeightKg else { return }
        let feedback = OnboardingTargetWeightRulerHaptics.feedback(
            from: lastTrackedGoalKg,
            to: kg,
            marks: &hapticBoundaryMarks
        )
        lastTrackedGoalKg = kg
        OnboardingTargetWeightRulerHaptics.play(feedback)
    }

    // MARK: - Binding (display units → canonical kg)

    private var displayValue: Double {
        OnboardingTargetWeightValues.displayGoalValue(from: formState)
    }

    private var displayBinding: Binding<Double> {
        Binding(
            get: { displayValue },
            set: { newDisplay in
                OnboardingTargetWeightValues.setGoalFromDisplay(newDisplay, in: &formState)
            }
        )
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
