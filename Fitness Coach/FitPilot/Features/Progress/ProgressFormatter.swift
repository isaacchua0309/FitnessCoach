//
//  ProgressFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight display formatting for Progress.
//
//  Formatting only. No services, AI, SwiftData, or trend calculations.
//

import Foundation

enum ProgressFormatter {
    static func compactKg(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f kg", value)
    }

    static func kg(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f kg", value)
    }

    static func kgChange(_ value: Double?) -> String {
        guard let value else { return "--" }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value)) kg"
    }

    static func grams(_ value: Double?) -> String {
        guard let value else { return "--" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : "\(String(format: "%.1f", value))g"
    }

    static func kcal(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value) kcal"
    }

    static func ml(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value) ml"
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int((value * 100).rounded()))%"
    }

    static func weeks(_ value: Double?) -> String {
        guard let value else { return "--" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) weeks"
            : "\(String(format: "%.1f", value)) weeks"
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "--" }
        return value.formatted(date: .abbreviated, time: .omitted)
    }

    static func monthYear(_ value: Date?) -> String {
        guard let value else { return "—" }
        return value.formatted(.dateTime.month(.abbreviated).year())
    }

    static func trendDirection(_ direction: WeightTrendDirection) -> String {
        switch direction {
        case .decreasing:
            return "Decreasing"
        case .increasing:
            return "Increasing"
        case .stable:
            return "Stable"
        case .insufficientData:
            return "Need more data"
        }
    }

    static func confidence(_ confidence: ConfidenceLevel) -> String {
        switch confidence {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }

    static func shortConfidence(_ confidence: ConfidenceLevel) -> String {
        switch confidence {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}
