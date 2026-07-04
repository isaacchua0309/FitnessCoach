//
//  HealthOSLogFormatting.swift
//  Fitness Coach
//
//  Forma — Shared os.Logger message formatting for Health modules.
//

import Foundation

enum HealthOSLogFormatting {

    /// Formats a log line with sorted key=value metadata for production os.Logger output.
    static func message(_ message: String, fields: [String: String]) -> String {
        let sanitized = LogRedactor.sanitizeLogFields(fields)
        guard !sanitized.isEmpty else { return message }
        return LogRedactor.formatLine(message: message, fields: sanitized)
    }
}
