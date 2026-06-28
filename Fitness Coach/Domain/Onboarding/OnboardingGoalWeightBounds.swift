//
//  OnboardingGoalWeightBounds.swift
//  Fitness Coach
//
//  Forma — Goal weight picker ranges and display helpers for onboarding.
//

import Foundation

enum OnboardingGoalWeightBounds {

    static let minimumWeightKg = 35.0
    static let maximumWeightKg = 200.0
    static let gainHeadroomKg = 25.0
    static let metricStepKg = 0.5
    static let imperialStepLb = 1.0

    static func rangeKg(currentWeightKg: Double, heightCm: Double?) -> ClosedRange<Double> {
        let healthyMinimum = minimumGoalKg(forHeightCm: heightCm) ?? minimumWeightKg
        let lower = max(minimumWeightKg, healthyMinimum)
        let upper = min(maximumWeightKg, currentWeightKg + gainHeadroomKg)
        let inclusiveLower = min(lower, currentWeightKg)
        let inclusiveUpper = max(upper, currentWeightKg)
        if inclusiveLower <= inclusiveUpper {
            return inclusiveLower...inclusiveUpper
        }
        return currentWeightKg...currentWeightKg
    }

    static func minimumGoalKg(forHeightCm heightCm: Double?) -> Double? {
        guard let heightCm, heightCm > 0 else { return nil }
        let heightM = heightCm / 100
        let minimumKg = OnboardingGoalProjectionBuilder.minimumHealthyGoalBMI * heightM * heightM
        guard minimumKg > 0 else { return nil }
        return (minimumKg * 2).rounded() / 2
    }

    static func displayRange(
        currentWeightKg: Double,
        heightCm: Double?,
        unitSystem: UnitSystem
    ) -> ClosedRange<Double> {
        let metricRange = rangeKg(currentWeightKg: currentWeightKg, heightCm: heightCm)
        switch unitSystem {
        case .metric:
            return metricRange
        case .imperial:
            let lower = metricRange.lowerBound * OnboardingFormState.poundsPerKilogram
            let upper = metricRange.upperBound * OnboardingFormState.poundsPerKilogram
            return lower...upper
        }
    }

    static func displayStep(for unitSystem: UnitSystem) -> Double {
        unitSystem == .metric ? metricStepKg : imperialStepLb
    }

    static func weightSummary(
        valueKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let display = displayValue(fromKg: valueKg, unitSystem: unitSystem)
        let unit = OnboardingFormatter.weightUnitAbbreviation(for: unitSystem)
        return "\(formatDisplay(display)) \(unit)"
    }

    static func changeSummary(
        currentKg: Double,
        goalKg: Double,
        unitSystem: UnitSystem
    ) -> String {
        let deltaKg = goalKg - currentKg
        if abs(deltaKg) <= FormaCalculationConstants.goalDirectionEpsilonKg {
            return FormaProductCopy.Onboarding.V2.Goal.changeMaintainLabel
        }

        let magnitudeKg = abs(deltaKg)
        let displayMagnitude = displayValue(fromKg: magnitudeKg, unitSystem: unitSystem)
        let unit = OnboardingFormatter.weightUnitAbbreviation(for: unitSystem)
        let valueText = formatDisplay(displayMagnitude)

        if deltaKg < 0 {
            return "\(FormaProductCopy.Onboarding.V2.Goal.changeLosePrefix) \(valueText) \(unit)"
        }
        return "\(FormaProductCopy.Onboarding.V2.Goal.changeGainPrefix) \(valueText) \(unit)"
    }

    static func displayValue(fromKg kg: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return kg
        case .imperial:
            return kg * OnboardingFormState.poundsPerKilogram
        }
    }

    static func metricValue(fromDisplay display: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return display
        case .imperial:
            return display / OnboardingFormState.poundsPerKilogram
        }
    }

    private static func formatDisplay(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value.rounded()))"
            : String(format: "%.1f", value)
    }
}

extension OnboardingFormState {

    var parsedHeightCm: Double? {
        let trimmed = heightCmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    mutating func applyGoalWeightDefaultIfNeeded() {
        guard goalWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let current = parsedCurrentWeightKg else {
            return
        }
        goalWeightKgText = Self.formatStoredMetric(current)
    }

    private static func formatStoredMetric(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 0.1) == 0 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}
