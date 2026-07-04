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

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.todayAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "TodayAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
