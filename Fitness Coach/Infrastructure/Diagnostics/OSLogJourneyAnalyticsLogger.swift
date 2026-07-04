//
//  OSLogJourneyAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Journey analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogJourneyAnalyticsLogger: JourneyAnalyticsLogging {

    func log(_ event: JourneyAnalyticsEvent, properties: JourneyAnalyticsProperties) {
        #if DEBUG
        JourneyAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum JourneyAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "JourneyAnalytics")

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.journeyAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "JourneyAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
