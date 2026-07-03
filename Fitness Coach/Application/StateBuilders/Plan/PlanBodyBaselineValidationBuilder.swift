//
//  PlanBodyBaselineValidationBuilder.swift
//  Fitness Coach
//
//  Forma — Height and weight validation for Edit Plan body baseline step.
//

import Foundation

struct PlanBodyBaselineFieldValidation: Equatable, Sendable {
    let heightMessage: String?
    let weightMessage: String?

    var isValid: Bool {
        heightMessage == nil && weightMessage == nil
    }
}

enum PlanBodyBaselineValidationBuilder {

    static func validate(
        heightText: String,
        weightText: String
    ) -> PlanBodyBaselineFieldValidation {
        PlanBodyBaselineFieldValidation(
            heightMessage: validateHeight(heightText),
            weightMessage: validateWeight(weightText)
        )
    }

    private static func validateHeight(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
            return FormaProductCopy.PlanEditBodyBaseline.validationEnterHeight
        }
        guard OnboardingPickerDefaults.metricHeightCmRange.contains(value) else {
            return FormaProductCopy.PlanEditBodyBaseline.validationHeightOutOfRange
        }
        return nil
    }

    private static func validateWeight(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else {
            return FormaProductCopy.PlanEditBodyBaseline.validationEnterWeight
        }
        guard OnboardingPickerDefaults.metricWeightKgRange.contains(value) else {
            return FormaProductCopy.PlanEditBodyBaseline.validationWeightOutOfRange
        }
        return nil
    }
}
