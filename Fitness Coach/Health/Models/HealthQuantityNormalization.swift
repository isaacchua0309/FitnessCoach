//
//  HealthQuantityNormalization.swift
//  Fitness Coach
//
//  Forma — Pure unit normalization helpers for Health Intelligence.
//

import Foundation

enum HealthQuantityNormalization {

    static func kilocalories(value: Double, unitSymbol: String) -> Double {
        let unit = normalizedUnit(unitSymbol)
        switch unit {
        case "kcal", "kilocalorie", "kilocalories":
            return nonNegative(value)
        case "cal", "calorie", "calories":
            return nonNegative(value / 1_000.0)
        case "kj", "kilojoule", "kilojoules":
            return nonNegative(value / 4.184)
        default:
            return nonNegative(value)
        }
    }

    static func minutes(value: Double, unitSymbol: String) -> Double {
        let unit = normalizedUnit(unitSymbol)
        switch unit {
        case "min", "minute", "minutes":
            return nonNegative(value)
        case "s", "sec", "second", "seconds":
            return nonNegative(value / 60.0)
        case "hr", "hour", "hours":
            return nonNegative(value * 60.0)
        default:
            return nonNegative(value)
        }
    }

    static func kilograms(value: Double, unitSymbol: String) -> Double {
        let unit = normalizedUnit(unitSymbol)
        switch unit {
        case "kg", "kilogram", "kilograms":
            return nonNegative(value)
        case "g", "gram", "grams":
            return nonNegative(value / 1_000.0)
        case "lb", "lbs", "pound", "pounds":
            return nonNegative(value * 0.453_592_37)
        default:
            return nonNegative(value)
        }
    }

    static func beatsPerMinute(value: Double, unitSymbol: String) -> Double {
        let unit = normalizedUnit(unitSymbol)
        switch unit {
        case "bpm", "count/min", "beats/min", "beats per minute":
            return nonNegative(value)
        case "hz", "hertz":
            return nonNegative(value * 60.0)
        default:
            return nonNegative(value)
        }
    }

    static func milliseconds(value: Double, unitSymbol: String) -> Double {
        let unit = normalizedUnit(unitSymbol)
        switch unit {
        case "ms", "millisecond", "milliseconds":
            return nonNegative(value)
        case "s", "sec", "second", "seconds":
            return nonNegative(value * 1_000.0)
        default:
            return nonNegative(value)
        }
    }

    static func stepCount(value: Double, unitSymbol: String) -> Int {
        let unit = normalizedUnit(unitSymbol)
        switch unit {
        case "count", "step", "steps", "":
            return max(Int(value.rounded()), 0)
        default:
            return max(Int(value.rounded()), 0)
        }
    }

    // MARK: - Private

    private static func normalizedUnit(_ unitSymbol: String) -> String {
        unitSymbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func nonNegative(_ value: Double) -> Double {
        max(value, 0)
    }
}
