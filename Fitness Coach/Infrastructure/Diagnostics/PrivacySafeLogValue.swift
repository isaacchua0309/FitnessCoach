//
//  PrivacySafeLogValue.swift
//  Fitness Coach
//
//  Forma — Typed, privacy-safe log field values for production diagnostics.
//

import Foundation

/// A value that is safe to emit in Release logs and analytics traces.
enum PrivacySafeLogValue: Equatable, Sendable {
    case bool(Bool)
    case count(Int)
    case category(String)
    case durationMs(Int)
    case uidHash(String)
    case eventName(String)
    case status(String)
    case textLength(Int)
    case bucket(String)

    var logString: String {
        switch self {
        case .bool(let value):
            return value ? "true" : "false"
        case .count(let value):
            return String(max(0, value))
        case .category(let value), .eventName(let value), .status(let value), .bucket(let value):
            return value
        case .durationMs(let value):
            return String(max(0, value))
        case .uidHash(let value):
            return value
        case .textLength(let value):
            return String(max(0, value))
        }
    }
}

enum PrivacySafeLogFields {

    /// Builds a string dictionary from typed safe values.
    static func make(_ pairs: [String: PrivacySafeLogValue]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.key, $0.value.logString) })
    }

    /// Merges safe fields with redacted sanitization as a final guard.
    static func sanitized(_ pairs: [String: PrivacySafeLogValue]) -> [String: String] {
        LogRedactor.sanitizeLogFields(make(pairs))
    }
}
