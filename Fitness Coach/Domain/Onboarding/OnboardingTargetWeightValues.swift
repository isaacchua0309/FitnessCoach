//
//  OnboardingTargetWeightValues.swift
//  Fitness Coach
//
//  Forma — Target weight math for onboarding (absolute goal ruler).
//

import Foundation

enum OnboardingTargetWeightValues {

    static let rulerStepKg = 0.1
    static let rulerStepLb = 0.2
    private static let rulerLossWindowFraction = 0.33
    private static let rulerGainWindowFraction = 0.25
    private static let rulerMinimumLossSpanKg = 25.0
    private static let rulerMinimumGainSpanKg = 15.0

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

    // MARK: - Goal-weight ruler (absolute scale)

    static func goalWeightRangeKg(
        currentWeightKg: Double,
        heightCm: Double?
    ) -> ClosedRange<Double> {
        OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentWeightKg,
            heightCm: heightCm
        )
    }

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
        let currentMetric = snapToRulerStep(currentWeightKg, step: rulerStepKg)
        let goalMetric = snapToRulerStep(selectedGoalKg ?? currentMetric, step: rulerStepKg)

        let maxLossKg = currentMetric - safety.lowerBound
        let maxGainKg = safety.upperBound - currentMetric

        let lossSpan = min(
            maxLossKg,
            max(rulerMinimumLossSpanKg, currentMetric * rulerLossWindowFraction)
        )
        let gainSpan = min(
            maxGainKg,
            max(rulerMinimumGainSpanKg, currentMetric * rulerGainWindowFraction)
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
                step: rulerStepKg
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
                step: rulerStepLb
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

    static func rulerValues(from formState: OnboardingFormState) -> [Double] {
        guard let range = goalWeightRangeDisplay(from: formState) else { return [] }
        return OnboardingRulerMath.buildValues(
            in: range,
            step: rulerStep(for: formState.unitSystem)
        )
    }

    static func resolvedRulerDisplayValue(from formState: OnboardingFormState) -> Double {
        if let display = resolvedGoalDisplay(from: formState) {
            return display
        }
        guard let currentKg = formState.parsedCurrentWeightKg else { return 0 }
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: currentKg,
            unitSystem: formState.unitSystem
        )
    }

    static func resolvedGoalDisplayIsInRulerRange(from formState: OnboardingFormState) -> Bool {
        let values = rulerValues(from: formState)
        guard !values.isEmpty else { return false }
        let display = resolvedRulerDisplayValue(from: formState)
        guard let index = OnboardingRulerMath.index(for: display, in: values) else { return false }
        return abs(values[index] - display) <= rulerStep(for: formState.unitSystem) / 2
    }

    static func rulerIdentity(for formState: OnboardingFormState) -> String {
        let current = formState.parsedCurrentWeightKg.map { String(format: "%.1f", $0) } ?? "nil"
        let goal = formState.parsedGoalWeightKg.map { String(format: "%.1f", $0) } ?? "nil"
        return "\(current)-\(goal)-\(formState.unitSystem.rawValue)"
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

    static func rulerIndexForGoalWeight(
        goalKg: Double,
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> Int? {
        let displayGoal = OnboardingGoalWeightBounds.displayValue(
            fromKg: goalKg,
            unitSystem: unitSystem
        )
        let values = OnboardingRulerMath.buildValues(
            in: goalWeightRangeDisplay(
                currentWeightKg: currentWeightKg,
                heightCm: heightCm,
                unitSystem: unitSystem,
                selectedGoalKg: goalKg
            ),
            step: rulerStep(for: unitSystem)
        )
        return OnboardingRulerMath.index(for: displayGoal, in: values)
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
        let maxLoss = max(0, -deltaRange.lowerBound)
        return alignedDeltaRange(minDelta: 0, maxDelta: maxLoss, step: rulerStepKg)
    }

    static func gainRangeKg(
        currentWeightKg: Double,
        heightCm: Double?
    ) -> ClosedRange<Double> {
        let deltaRange = deltaRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        let maxGain = max(0, deltaRange.upperBound)
        return alignedDeltaRange(minDelta: 0, maxDelta: maxGain, step: rulerStepKg)
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
            return alignedDeltaRange(minDelta: lower, maxDelta: upper, step: rulerStepLb)
        }
    }

    static func gainRangeDisplay(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> ClosedRange<Double> {
        let metricRange = gainRangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        switch unitSystem {
        case .metric:
            return metricRange
        case .imperial:
            let lower = OnboardingGoalWeightBounds.displayValue(fromKg: metricRange.lowerBound, unitSystem: .imperial)
            let upper = OnboardingGoalWeightBounds.displayValue(fromKg: metricRange.upperBound, unitSystem: .imperial)
            return alignedDeltaRange(minDelta: lower, maxDelta: upper, step: rulerStepLb)
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

    static func resolvedGainKg(from formState: OnboardingFormState) -> Double {
        max(0, resolvedDeltaKg(from: formState))
    }

    static func resolvedGainDisplay(from formState: OnboardingFormState) -> Double {
        let gainKg = resolvedGainKg(from: formState)
        return OnboardingGoalWeightBounds.displayValue(
            fromKg: gainKg,
            unitSystem: formState.unitSystem
        )
    }

    static func setGoalFromGainDisplay(_ gainDisplay: Double, in formState: inout OnboardingFormState) {
        let gainKg = OnboardingGoalWeightBounds.metricValue(
            fromDisplay: gainDisplay,
            unitSystem: formState.unitSystem
        )
        setGoalFromDeltaKg(max(0, gainKg), in: &formState)
    }

    static func usesGainRuler(for formState: OnboardingFormState) -> Bool {
        resolvedDeltaKg(from: formState) > FormaCalculationConstants.goalDirectionEpsilonKg
    }

    static func rulerIndexForZeroLoss(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> Int? {
        let values = OnboardingRulerMath.buildValues(
            in: lossRangeDisplay(
                currentWeightKg: currentWeightKg,
                heightCm: heightCm,
                unitSystem: unitSystem
            ),
            step: rulerStep(for: unitSystem)
        )
        return OnboardingRulerMath.index(for: 0, in: values)
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

    private static func snapToRulerStep(_ valueKg: Double, step: Double) -> Double {
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
        let stepped = (goalKg / rulerStepKg).rounded() * rulerStepKg
        return min(max(stepped, allowed.lowerBound), allowed.upperBound)
    }
}
