//
//  OnboardingV4HeightWeightValues.swift
//  Fitness Coach
//
//  Forma — Canonical metric storage and imperial conversion for v4 height/weight.
//

import Foundation

enum OnboardingV4HeightWeightValues {

    static let imperialFeetRange = 3...7
    static let imperialInchesRange = 0...11

    static func applyDefaultsIfNeeded(to formState: inout OnboardingFormState) {
        if formState.heightCmText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formState.heightCmText = formatStoredMetric(OnboardingV3PickerDefaults.defaultHeightCm)
        }
        if formState.currentWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formState.currentWeightKgText = formatStoredMetric(OnboardingV3PickerDefaults.defaultWeightKg)
        }
    }

    static func resolvedHeightCm(from formState: OnboardingFormState) -> Double {
        if let parsed = parsedMetric(formState.heightCmText) {
            return parsed
        }
        return OnboardingV3PickerDefaults.defaultHeightCm
    }

    static func resolvedWeightKg(from formState: OnboardingFormState) -> Double {
        if let parsed = parsedMetric(formState.currentWeightKgText) {
            return parsed
        }
        return OnboardingV3PickerDefaults.defaultWeightKg
    }

    static func setHeightCm(_ value: Double, in formState: inout OnboardingFormState) {
        formState.heightCmText = formatStoredMetric(value)
    }

    static func setWeightKg(_ value: Double, in formState: inout OnboardingFormState) {
        formState.currentWeightKgText = formatStoredMetric(value)
    }

    static func imperialFeet(from formState: OnboardingFormState) -> Int {
        let totalInches = totalImperialInches(from: formState)
        return totalInches / 12
    }

    static func imperialInches(from formState: OnboardingFormState) -> Int {
        let totalInches = totalImperialInches(from: formState)
        return totalInches % 12
    }

    static func setImperialHeight(feet: Int, inches: Int, in formState: inout OnboardingFormState) {
        let totalInches = feet * 12 + inches
        let clamped = min(
            max(totalInches, Int(OnboardingV3PickerDefaults.imperialHeightInchesRange.lowerBound.rounded())),
            Int(OnboardingV3PickerDefaults.imperialHeightInchesRange.upperBound.rounded())
        )
        let cm = Double(clamped) * OnboardingFormState.centimetersPerInch
        setHeightCm(cm, in: &formState)
    }

    static func resolvedWeightLb(from formState: OnboardingFormState) -> Double {
        (resolvedWeightKg(from: formState) * OnboardingFormState.poundsPerKilogram).rounded()
    }

    static func setWeightLb(_ pounds: Double, in formState: inout OnboardingFormState) {
        let kg = pounds / OnboardingFormState.poundsPerKilogram
        setWeightKg(kg, in: &formState)
    }

    static func validate(formState: OnboardingFormState) throws {
        let height = try validatedHeightCm(from: formState)
        let weight = try validatedWeightKg(from: formState)
        try validateHeightCm(height)
        try validateWeightKg(weight)
    }

    static func validateHeightCm(_ value: Double) throws {
        guard OnboardingV3PickerDefaults.metricHeightCmRange.contains(value) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.V4.Validation.heightOutOfRange
            )
        }
    }

    static func validateWeightKg(_ value: Double) throws {
        guard OnboardingV3PickerDefaults.metricWeightKgRange.contains(value) else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.V4.Validation.weightOutOfRange
            )
        }
    }

    static func formatStoredMetric(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private static func validatedHeightCm(from formState: OnboardingFormState) throws -> Double {
        guard let value = parsedMetric(formState.heightCmText) else {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.Validation.height)
        }
        return value
    }

    private static func validatedWeightKg(from formState: OnboardingFormState) throws -> Double {
        guard let value = parsedMetric(formState.currentWeightKgText) else {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.Validation.currentWeight)
        }
        return value
    }

    private static func parsedMetric(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private static func totalImperialInches(from formState: OnboardingFormState) -> Int {
        let cm = resolvedHeightCm(from: formState)
        return Int((cm / OnboardingFormState.centimetersPerInch).rounded())
    }
}
