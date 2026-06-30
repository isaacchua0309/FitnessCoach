//
//  OSLogTodayAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Today analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogTodayAnalyticsLogger: TodayAnalyticsLogging {

    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties) {
        #if DEBUG
        TodayAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum TodayAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "TodayAnalytics")

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_TODAY_ANALYTICS_TRACE"] != "0"
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[TodayAnalytics] \(message)"
            : "[TodayAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
