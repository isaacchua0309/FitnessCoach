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

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_THEME_ANALYTICS_TRACE"] != "0"
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[ThemeAnalytics] \(message)"
            : "[ThemeAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
