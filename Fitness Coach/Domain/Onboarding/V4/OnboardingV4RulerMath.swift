//
//  OnboardingV4RulerMath.swift
//  Fitness Coach
//
//  Forma — Pure value/index math for v4 horizontal ruler pickers.
//

import Foundation

enum OnboardingV4RulerMath {

    static func buildValues(
        in range: ClosedRange<Double>,
        step: Double
    ) -> [Double] {
        OnboardingPickerValueSequence.decimals(in: range, step: step)
    }

    static func index(for value: Double, in values: [Double]) -> Int? {
        guard !values.isEmpty else { return nil }
        var bestIndex = 0
        var bestDistance = abs(values[0] - value)
        for (index, candidate) in values.enumerated() where index > 0 {
            let distance = abs(candidate - value)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    static func snapValue(_ value: Double, in values: [Double]) -> Double {
        guard let index = index(for: value, in: values), values.indices.contains(index) else {
            return value
        }
        return values[index]
    }

    static func value(at index: Int, in values: [Double]) -> Double? {
        guard values.indices.contains(index) else { return nil }
        return values[index]
    }

    static func clampedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index, 0), count - 1)
    }

    static func accessibilityValueLabel(
        value: Double,
        unitLabel: String,
        formatter: (Double) -> String
    ) -> String {
        let formatted = formatter(value)
        if unitLabel.isEmpty {
            return formatted
        }
        return "\(formatted) \(unitLabel)"
    }
}
