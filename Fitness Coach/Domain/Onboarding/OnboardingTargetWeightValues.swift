//
//  OnboardingTargetWeightValues.swift
//  Fitness Coach
//
//  Forma — Loss-based target weight math for onboarding.
//

import Foundation

enum OnboardingTargetWeightValues {

    /// Default loss ≈ 5% of current weight, snapped to picker step and clamped to safe bounds.
    static let defaultLossFraction = 0.05

    static func applyDefaultsIfNeeded(to formState: inout OnboardingFormState) {
        formState.selectPaceChoice(.moderate)
        formState.syncAggressivenessFromPaceChoice()

        guard let currentKg = formState.parsedCurrentWeightKg else { return }

        if !formState.goalWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           formState.parsedGoalWeightKg != nil {
            return
        }

        let defaultLoss = defaultLossKg(
            currentWeightKg: currentKg,
            heightCm: formState.parsedHeightCm
        )
        setGoalFromLossKg(defaultLoss, in: &formState)
    }

    static func lossRangeKg(
        currentWeightKg: Double,
        heightCm: Double?
    ) -> ClosedRange<Double> {
        let goalRange = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentWeightKg,
            heightCm: heightCm
        )
        let minimumGoalKg = goalRange.lowerBound
        let maximumLossKg = max(0, currentWeightKg - minimumGoalKg)
        return 0...maximumLossKg
    }

    static func lossRangeDisplay(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> ClosedRange<Double> {
        let metricRange = lossRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        switch unitSystem {
        case .metric:
            return metricRange
        case .imperial:
            let lower = OnboardingGoalWeightBounds.displayValue(fromKg: metricRange.lowerBound, unitSystem: .imperial)
            let upper = OnboardingGoalWeightBounds.displayValue(fromKg: metricRange.upperBound, unitSystem: .imperial)
            return lower...upper
        }
    }

    static func displayStep(for unitSystem: UnitSystem) -> Double {
        OnboardingGoalWeightBounds.displayStep(for: unitSystem)
    }

    static func goalKg(currentWeightKg: Double, lossKg: Double) -> Double {
        currentWeightKg - max(0, lossKg)
    }

    static func lossKg(currentWeightKg: Double, goalWeightKg: Double) -> Double? {
        let loss = currentWeightKg - goalWeightKg
        guard loss >= 0 else { return nil }
        return loss
    }

    static func resolvedLossKg(from formState: OnboardingFormState) -> Double {
        guard let current = formState.parsedCurrentWeightKg else { return 0 }
        if let goal = formState.parsedGoalWeightKg,
           let loss = lossKg(currentWeightKg: current, goalWeightKg: goal) {
            return loss
        }
        return defaultLossKg(currentWeightKg: current, heightCm: formState.parsedHeightCm)
    }

    static func resolvedLossDisplay(from formState: OnboardingFormState) -> Double {
        let lossKg = resolvedLossKg(from: formState)
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: lossKg,
            unitSystem: formState.unitSystem
        )
    }

    static func resolvedGoalKg(from formState: OnboardingFormState) -> Double? {
        guard let current = formState.parsedCurrentWeightKg else { return nil }
        return goalKg(currentWeightKg: current, lossKg: resolvedLossKg(from: formState))
    }

    static func setGoalFromLossKg(_ lossKg: Double, in formState: inout OnboardingFormState) {
        guard let current = formState.parsedCurrentWeightKg else { return }
        let clampedLoss = clampedLossKg(
            lossKg,
            currentWeightKg: current,
            heightCm: formState.parsedHeightCm
        )
        let goal = goalKg(currentWeightKg: current, lossKg: clampedLoss)
        formState.goalWeightKgText = OnboardingHeightWeightValues.formatStoredMetric(goal)
    }

    static func setGoalFromLossDisplay(_ lossDisplay: Double, in formState: inout OnboardingFormState) {
        let lossKg = OnboardingGoalWeightBounds.metricValue(
            fromDisplay: lossDisplay,
            unitSystem: formState.unitSystem
        )
        setGoalFromLossKg(lossKg, in: &formState)
    }

    static func validate(formState: OnboardingFormState) throws {
        guard let currentKg = formState.parsedCurrentWeightKg else {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.Validation.currentWeight)
        }

        guard let goalKg = formState.parsedGoalWeightKg else {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.Validation.goalWeight)
        }

        let allowedGoals = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentKg,
            heightCm: formState.parsedHeightCm
        )
        guard allowedGoals.contains(goalKg) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.TargetWeight.unsafeGoalMessage
            )
        }

        if let heightCm = formState.parsedHeightCm,
           OnboardingGoalProjectionBuilder.isGoalBMITooLow(goalWeightKg: goalKg, heightCm: heightCm) {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.V2.Goal.bmiWarning)
        }

        guard let loss = lossKg(currentWeightKg: currentKg, goalWeightKg: goalKg) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.V2.Goal.goalMustBeBelowCurrent
            )
        }

        let allowedLoss = lossRangeKg(currentWeightKg: currentKg, heightCm: formState.parsedHeightCm)
        guard allowedLoss.contains(loss) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.TargetWeight.unsafeGoalMessage
            )
        }
    }

    static func currentToTargetSummary(for formState: OnboardingFormState) -> String? {
        guard let current = formState.parsedCurrentWeightKg,
              let goal = resolvedGoalKg(from: formState) else {
            return nil
        }
        let currentLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: current,
            unitSystem: formState.unitSystem
        )
        let targetLabel = OnboardingGoalWeightBounds.weightSummary(
            valueKg: goal,
            unitSystem: formState.unitSystem
        )
        return FormaProductCopy.Onboarding.Flow.TargetWeight.currentToTargetSummary(
            current: currentLabel,
            target: targetLabel
        )
    }

    static func targetWeightCenterLabel(for formState: OnboardingFormState) -> String? {
        guard let goal = resolvedGoalKg(from: formState) else { return nil }
        return OnboardingGoalWeightBounds.weightSummary(
            valueKg: goal,
            unitSystem: formState.unitSystem
        )
    }

    private static func defaultLossKg(currentWeightKg: Double, heightCm: Double?) -> Double {
        let allowed = lossRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        guard allowed.upperBound > 0 else { return 0 }

        let raw = currentWeightKg * defaultLossFraction
        let stepped = (raw * 2).rounded() / 2
        let minimumSuggested = min(allowed.upperBound, OnboardingGoalWeightBounds.metricStepKg)
        return min(max(stepped, minimumSuggested), allowed.upperBound)
    }

    private static func clampedLossKg(
        _ lossKg: Double,
        currentWeightKg: Double,
        heightCm: Double?
    ) -> Double {
        let allowed = lossRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        return min(max(lossKg, allowed.lowerBound), allowed.upperBound)
    }
}
