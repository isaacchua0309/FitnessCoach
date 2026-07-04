//
//  OSLogSettingsAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Settings analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogSettingsAnalyticsLogger: SettingsAnalyticsLogging {

    func log(_ event: SettingsAnalyticsEvent, properties: SettingsAnalyticsProperties) {
        #if DEBUG
        SettingsAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum SettingsAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "SettingsAnalytics")

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.settingsAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[SettingsAnalytics] \(message)"
            : "[SettingsAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
