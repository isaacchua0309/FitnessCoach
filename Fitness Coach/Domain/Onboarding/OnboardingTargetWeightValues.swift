//
//  OnboardingTargetWeightValues.swift
//  Fitness Coach
//
//  Forma — Target weight math for onboarding (delta ruler → goal weight).
//

import Foundation

enum OnboardingTargetWeightValues {

    static let rulerStepKg = 0.1
    static let rulerStepLb = 0.2

    static func applyDefaultsIfNeeded(to formState: inout OnboardingFormState) {
        formState.selectPaceChoice(.moderate)
        formState.syncAggressivenessFromPaceChoice()

        guard let currentKg = formState.parsedCurrentWeightKg else { return }

        if !formState.goalWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           formState.parsedGoalWeightKg != nil {
            return
        }

        setGoalWeightKg(currentKg, in: &formState)
    }

    // MARK: - Delta range (ruler)

    static func deltaRangeKg(
        currentWeightKg: Double,
        heightCm: Double?
    ) -> ClosedRange<Double> {
        let goalRange = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentWeightKg,
            heightCm: heightCm
        )
        let minDelta = goalRange.lowerBound - currentWeightKg
        let maxDelta = goalRange.upperBound - currentWeightKg
        return alignedDeltaRange(minDelta: minDelta, maxDelta: maxDelta, step: rulerStepKg)
    }

    static func deltaRangeDisplay(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> ClosedRange<Double> {
        let metricRange = deltaRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        switch unitSystem {
        case .metric:
            return metricRange
        case .imperial:
            let lower = OnboardingGoalWeightBounds.displayValue(
                fromKg: metricRange.lowerBound,
                unitSystem: .imperial
            )
            let upper = OnboardingGoalWeightBounds.displayValue(
                fromKg: metricRange.upperBound,
                unitSystem: .imperial
            )
            return alignedDeltaRange(minDelta: lower, maxDelta: upper, step: rulerStepLb)
        }
    }

    static func rulerStep(for unitSystem: UnitSystem) -> Double {
        unitSystem == .metric ? rulerStepKg : rulerStepLb
    }

    // MARK: - Resolved values

    static func resolvedDeltaKg(from formState: OnboardingFormState) -> Double {
        guard let current = formState.parsedCurrentWeightKg else { return 0 }
        guard let goal = resolvedGoalKg(from: formState) else { return 0 }
        return goal - current
    }

    static func resolvedDeltaDisplay(from formState: OnboardingFormState) -> Double {
        let deltaKg = resolvedDeltaKg(from: formState)
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: deltaKg,
            unitSystem: formState.unitSystem
        )
    }

    static func resolvedGoalKg(from formState: OnboardingFormState) -> Double? {
        guard let current = formState.parsedCurrentWeightKg else { return nil }
        return formState.parsedGoalWeightKg ?? current
    }

    // MARK: - Mutators

    static func setGoalWeightKg(_ goalKg: Double, in formState: inout OnboardingFormState) {
        guard let current = formState.parsedCurrentWeightKg else { return }
        let clamped = clampedGoalKg(
            goalKg,
            currentWeightKg: current,
            heightCm: formState.parsedHeightCm
        )
        formState.goalWeightKgText = OnboardingHeightWeightValues.formatStoredMetric(clamped)
    }

    static func setGoalFromDeltaKg(_ deltaKg: Double, in formState: inout OnboardingFormState) {
        guard let current = formState.parsedCurrentWeightKg else { return }
        setGoalWeightKg(current + deltaKg, in: &formState)
    }

    static func setGoalFromDeltaDisplay(_ deltaDisplay: Double, in formState: inout OnboardingFormState) {
        let deltaKg = OnboardingGoalWeightBounds.metricValue(
            fromDisplay: deltaDisplay,
            unitSystem: formState.unitSystem
        )
        setGoalFromDeltaKg(deltaKg, in: &formState)
    }

    /// Convenience for loss-only callers (tests, previews). Negative delta = loss.
    static func setGoalFromLossKg(_ lossKg: Double, in formState: inout OnboardingFormState) {
        setGoalFromDeltaKg(-max(0, lossKg), in: &formState)
    }

    static func setGoalFromLossDisplay(_ lossDisplay: Double, in formState: inout OnboardingFormState) {
        let lossKg = OnboardingGoalWeightBounds.metricValue(
            fromDisplay: lossDisplay,
            unitSystem: formState.unitSystem
        )
        setGoalFromLossKg(lossKg, in: &formState)
    }

    // MARK: - Legacy loss helpers (tests / migration)

    static func lossRangeKg(
        currentWeightKg: Double,
        heightCm: Double?
    ) -> ClosedRange<Double> {
        let deltaRange = deltaRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        return 0...max(0, -deltaRange.lowerBound)
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

    static func goalKg(currentWeightKg: Double, lossKg: Double) -> Double {
        currentWeightKg - max(0, lossKg)
    }

    static func lossKg(currentWeightKg: Double, goalWeightKg: Double) -> Double {
        currentWeightKg - goalWeightKg
    }

    static func resolvedLossKg(from formState: OnboardingFormState) -> Double {
        max(0, -resolvedDeltaKg(from: formState))
    }

    static func resolvedLossDisplay(from formState: OnboardingFormState) -> Double {
        let lossKg = resolvedLossKg(from: formState)
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: lossKg,
            unitSystem: formState.unitSystem
        )
    }

    // MARK: - Validation

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

        let allowedDelta = deltaRangeKg(currentWeightKg: currentKg, heightCm: formState.parsedHeightCm)
        let delta = goalKg - currentKg
        guard allowedDelta.contains(delta) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.TargetWeight.unsafeGoalMessage
            )
        }
    }

    // MARK: - Display copy

    static func currentToTargetSummary(for formState: OnboardingFormState) -> String? {
        guard let current = formState.parsedCurrentWeightKg,
              let goal = resolvedGoalKg(from: formState) else {
            return nil
        }
        let currentLabel = targetWeightLabel(valueKg: current, unitSystem: formState.unitSystem)
        let targetLabel = targetWeightLabel(valueKg: goal, unitSystem: formState.unitSystem)
        return FormaProductCopy.Onboarding.Flow.TargetWeight.currentToTargetSummary(
            current: currentLabel,
            target: targetLabel
        )
    }

    static func heroHeadline(for formState: OnboardingFormState) -> String? {
        guard let goal = resolvedGoalKg(from: formState) else { return nil }
        let target = targetWeightLabel(valueKg: goal, unitSystem: formState.unitSystem)
        return "Target \(target)"
    }

    static func differenceLabel(for formState: OnboardingFormState) -> String? {
        guard let current = formState.parsedCurrentWeightKg,
              let goal = resolvedGoalKg(from: formState) else {
            return nil
        }
        return differenceLabel(currentKg: current, goalKg: goal, unitSystem: formState.unitSystem)
    }

    static func differenceLabel(
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let deltaKg = goalKg - currentKg
        let unit = OnboardingFormatter.weightUnitAbbreviation(for: unitSystem)

        if abs(deltaKg) <= FormaCalculationConstants.goalDirectionEpsilonKg {
            return "\(formatOneDecimal(0)) \(unit)"
        }

        let magnitudeDisplay = OnboardingGoalWeightBounds.displayValue(
            fromKg: abs(deltaKg),
            unitSystem: unitSystem
        )
        if deltaKg < 0 {
            return "\(FormaProductCopy.Onboarding.V2.Goal.changeLosePrefix) \(formatOneDecimal(magnitudeDisplay)) \(unit)"
        }
        return "\(FormaProductCopy.Onboarding.V2.Goal.changeGainPrefix) \(formatOneDecimal(magnitudeDisplay)) \(unit)"
    }

    static func rulerCenterLabel(for formState: OnboardingFormState) -> String? {
        differenceLabel(for: formState)
    }

    static func targetWeightLabel(valueKg: Double, unitSystem: UnitSystem) -> String {
        let display = OnboardingGoalWeightBounds.displayValue(fromKg: valueKg, unitSystem: unitSystem)
        let unit = OnboardingFormatter.weightUnitAbbreviation(for: unitSystem)
        return "\(formatOneDecimal(display)) \(unit)"
    }

    static func deltaIsVisuallyZero(_ deltaKg: Double) -> Bool {
        abs(deltaKg) <= rulerStepKg / 2
    }

    static func rulerIndexForZeroDelta(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> Int? {
        let values = OnboardingRulerMath.buildValues(
            in: deltaRangeDisplay(
                currentWeightKg: currentWeightKg,
                heightCm: heightCm,
                unitSystem: unitSystem
            ),
            step: rulerStep(for: unitSystem)
        )
        return OnboardingRulerMath.index(for: 0, in: values)
    }

    // MARK: - Private

    private static func formatOneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func alignedDeltaRange(
        minDelta: Double,
        maxDelta: Double,
        step: Double
    ) -> ClosedRange<Double> {
        guard step > 0 else { return minDelta...maxDelta }
        let lower = floor(minDelta / step + 1e-9) * step
        let upper = ceil(maxDelta / step - 1e-9) * step
        if lower <= upper {
            return lower...upper
        }
        return 0...0
    }

    private static func clampedGoalKg(
        _ goalKg: Double,
        currentWeightKg: Double,
        heightCm: Double?
    ) -> Double {
        let allowed = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentWeightKg,
            heightCm: heightCm
        )
        let stepped = (goalKg / rulerStepKg).rounded() * rulerStepKg
        return min(max(stepped, allowed.lowerBound), allowed.upperBound)
    }
}
