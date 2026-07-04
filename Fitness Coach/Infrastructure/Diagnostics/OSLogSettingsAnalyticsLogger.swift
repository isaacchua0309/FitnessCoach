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
        LogRedactor.emitOSLogTrace(
            prefix: "SettingsAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
