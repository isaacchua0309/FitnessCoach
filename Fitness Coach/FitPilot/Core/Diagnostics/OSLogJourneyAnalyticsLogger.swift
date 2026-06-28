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

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_JOURNEY_ANALYTICS_TRACE"] != "0"
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[JourneyAnalytics] \(message)"
            : "[JourneyAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
