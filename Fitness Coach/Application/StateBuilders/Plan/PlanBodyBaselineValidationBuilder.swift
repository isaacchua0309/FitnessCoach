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
        switch PlanNumericInputParser.parsePositiveDecimal(text) {
        case .failure(.empty):
            return FormaProductCopy.PlanEditBodyBaseline.validationEnterHeight
        case .failure(.invalidFormat):
            return FormaProductCopy.PlanEditBodyBaseline.validationInvalidNumber
        case .failure(.nonPositive):
            return FormaProductCopy.PlanEditBodyBaseline.validationEnterHeight
        case .success(let value):
            guard OnboardingPickerDefaults.metricHeightCmRange.contains(value) else {
                return FormaProductCopy.PlanEditBodyBaseline.validationHeightOutOfRange
            }
            return nil
        }
    }

    private static func validateWeight(_ text: String) -> String? {
        switch PlanNumericInputParser.parsePositiveDecimal(text) {
        case .failure(.empty):
            return FormaProductCopy.PlanEditBodyBaseline.validationEnterWeight
        case .failure(.invalidFormat):
            return FormaProductCopy.PlanEditBodyBaseline.validationInvalidNumber
        case .failure(.nonPositive):
            return FormaProductCopy.PlanEditBodyBaseline.validationEnterWeight
        case .success(let value):
            guard OnboardingPickerDefaults.metricWeightKgRange.contains(value) else {
                return FormaProductCopy.PlanEditBodyBaseline.validationWeightOutOfRange
            }
            return nil
        }
    }
}
