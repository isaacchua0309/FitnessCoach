//
//  OSLogThemeAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for theme settings analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogThemeAnalyticsLogger: ThemeAnalyticsLogging {

    func log(_ event: ThemeAnalyticsEvent, properties: ThemeAnalyticsProperties) {
        #if DEBUG
        ThemeAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum ThemeAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "ThemeAnalytics")

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.themeAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "ThemeAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
