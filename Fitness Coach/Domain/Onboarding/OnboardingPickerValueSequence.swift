//
//  OnboardingPickerValueSequence.swift
//  Fitness Coach
//
//  Forma — Discrete value sequences for onboarding pickers.
//

import Foundation

enum OnboardingPickerValueSequence {
    static func integers(in range: ClosedRange<Int>, step: Int = 1) -> [Int] {
        guard step > 0 else { return [range.lowerBound] }
        return stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }
    }

    static func decimals(
        in range: ClosedRange<Double>,
        step: Double
    ) -> [Double] {
        guard step > 0 else { return [range.lowerBound] }
        var values: [Double] = []
        var current = range.lowerBound
        let epsilon = step / 10
        while current <= range.upperBound + epsilon {
            values.append((current * 100).rounded() / 100)
            current += step
        }
        return values
    }
}
