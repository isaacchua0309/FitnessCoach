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
        guard !fields.isEmpty else { return message }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(message) \(fieldLine)"
    }
}
