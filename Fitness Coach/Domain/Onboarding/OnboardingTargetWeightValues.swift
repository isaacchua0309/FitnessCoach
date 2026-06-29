//
//  OnboardingTargetWeightValues.swift
//  Fitness Coach
//
//  Forma — Target weight domain logic for onboarding (absolute goal selection).
//

import Foundation

enum OnboardingTargetWeightValues {

    static let selectionStepKg = 0.1
    static let selectionStepLb = 0.2
    private static let goalRangeLossWindowFraction = 0.33
    private static let goalRangeGainWindowFraction = 0.25
    private static let goalRangeMinimumLossSpanKg = 25.0
    private static let goalRangeMinimumGainSpanKg = 15.0

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

    static func selectionStep(for unitSystem: UnitSystem) -> Double {
        unitSystem == .metric ? selectionStepKg : selectionStepLb
    }

    // MARK: - Goal-weight display range (picker window)

    static func goalWeightRangeDisplay(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem,
        selectedGoalKg: Double? = nil
    ) -> ClosedRange<Double> {
        let safety = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentWeightKg,
            heightCm: heightCm
        )
        let currentMetric = snapToSelectionStep(currentWeightKg, step: selectionStepKg)
        let goalMetric = snapToSelectionStep(selectedGoalKg ?? currentMetric, step: selectionStepKg)

        let maxLossKg = currentMetric - safety.lowerBound
        let maxGainKg = safety.upperBound - currentMetric

        let lossSpan = min(
            maxLossKg,
            max(goalRangeMinimumLossSpanKg, currentMetric * goalRangeLossWindowFraction)
        )
        let gainSpan = min(
            maxGainKg,
            max(goalRangeMinimumGainSpanKg, currentMetric * goalRangeGainWindowFraction)
        )

        var lowerMetric = currentMetric - lossSpan
        var upperMetric = currentMetric + gainSpan

        lowerMetric = min(lowerMetric, currentMetric, goalMetric)
        upperMetric = max(upperMetric, currentMetric, goalMetric)

        lowerMetric = max(safety.lowerBound, lowerMetric)
        upperMetric = min(safety.upperBound, upperMetric)

        lowerMetric = min(lowerMetric, currentMetric, goalMetric)
        upperMetric = max(upperMetric, currentMetric, goalMetric)

        switch unitSystem {
        case .metric:
            let alignedLower = floor(lowerMetric)
            let alignedUpper = ceil(upperMetric)
            return alignedGoalWeightRange(
                lower: alignedLower,
                upper: alignedUpper,
                step: selectionStepKg
            )
        case .imperial:
            let lower = OnboardingGoalWeightBounds.displayValue(
                fromKg: lowerMetric,
                unitSystem: .imperial
            )
            let upper = OnboardingGoalWeightBounds.displayValue(
                fromKg: upperMetric,
                unitSystem: .imperial
            )
            return alignedGoalWeightRange(
                lower: lower,
                upper: upper,
                step: selectionStepLb
            )
        }
    }

    static func goalWeightRangeDisplay(from formState: OnboardingFormState) -> ClosedRange<Double>? {
        guard let currentKg = formState.parsedCurrentWeightKg else { return nil }
        return goalWeightRangeDisplay(
            currentWeightKg: currentKg,
            heightCm: formState.parsedHeightCm,
            unitSystem: formState.unitSystem,
            selectedGoalKg: resolvedGoalKg(from: formState)
        )
    }

    /// Display-unit goal for the target-weight selector (kg or lb).
    static func displayGoalValue(from formState: OnboardingFormState) -> Double {
        if let display = resolvedGoalDisplay(from: formState) {
            return display
        }
        guard let currentKg = formState.parsedCurrentWeightKg else { return 0 }
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: currentKg,
            unitSystem: formState.unitSystem
        )
    }

    /// Stable view identity when current weight or units change — not goal.
    /// Goal is excluded so dragging does not remount the ruler and kill scroll momentum.
    static func selectorIdentity(for formState: OnboardingFormState) -> String {
        let current = formState.parsedCurrentWeightKg.map { String(format: "%.1f", $0) } ?? "nil"
        return "\(current)-\(formState.unitSystem.rawValue)"
    }

    static func resolvedGoalDisplay(from formState: OnboardingFormState) -> Double? {
        guard let goalKg = resolvedGoalKg(from: formState) else { return nil }
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: goalKg,
            unitSystem: formState.unitSystem
        )
    }

    static func setGoalFromDisplay(_ display: Double, in formState: inout OnboardingFormState) {
        let kg = OnboardingGoalWeightBounds.metricValue(
            fromDisplay: display,
            unitSystem: formState.unitSystem
        )
        setGoalWeightKg(kg, in: &formState)
    }

    static func targetWeightTickFormatter(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Resolved values

    static func resolvedDeltaKg(from formState: OnboardingFormState) -> Double {
        guard let current = formState.parsedCurrentWeightKg else { return 0 }
        guard let goal = resolvedGoalKg(from: formState) else { return 0 }
        return goal - current
    }

    static func resolvedGoalKg(from formState: OnboardingFormState) -> Double? {
        guard formState.parsedCurrentWeightKg != nil else { return nil }
        return formState.parsedGoalWeightKg ?? formState.parsedCurrentWeightKg
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

    /// Sets goal from a signed delta in kg (negative = loss, positive = gain).
    static func setGoalFromDeltaKg(_ deltaKg: Double, in formState: inout OnboardingFormState) {
        guard let current = formState.parsedCurrentWeightKg else { return }
        setGoalWeightKg(current + deltaKg, in: &formState)
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

    /// Large numeric display for the target-weight step (without the "Target" prefix).
    static func displayValueHeadline(for formState: OnboardingFormState) -> String? {
        guard let goal = resolvedGoalKg(from: formState) else { return nil }
        return targetWeightLabel(valueKg: goal, unitSystem: formState.unitSystem)
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
            return FormaProductCopy.Onboarding.V2.Goal.changeMaintainLabel
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

    static func targetWeightLabel(valueKg: Double, unitSystem: UnitSystem) -> String {
        let display = OnboardingGoalWeightBounds.displayValue(fromKg: valueKg, unitSystem: unitSystem)
        let unit = OnboardingFormatter.weightUnitAbbreviation(for: unitSystem)
        return "\(formatOneDecimal(display)) \(unit)"
    }

    // MARK: - Private

    private static func formatOneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func alignedGoalWeightRange(
        lower: Double,
        upper: Double,
        step: Double
    ) -> ClosedRange<Double> {
        guard step > 0 else { return lower...upper }
        let alignedLower = floor(lower / step + 1e-9) * step
        let alignedUpper = ceil(upper / step - 1e-9) * step
        if alignedLower <= alignedUpper {
            return alignedLower...alignedUpper
        }
        return lower...lower
    }

    private static func snapToSelectionStep(_ valueKg: Double, step: Double) -> Double {
        guard step > 0 else { return valueKg }
        return (valueKg / step).rounded() * step
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
        let stepped = (goalKg / selectionStepKg).rounded() * selectionStepKg
        return min(max(stepped, allowed.lowerBound), allowed.upperBound)
    }
}
