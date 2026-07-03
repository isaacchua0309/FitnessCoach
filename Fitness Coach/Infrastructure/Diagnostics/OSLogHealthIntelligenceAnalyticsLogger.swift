//
//  OSLogHealthIntelligenceAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Health Intelligence analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogHealthIntelligenceAnalyticsLogger: HealthIntelligenceAnalyticsLogging {

    func log(_ event: HealthIntelligenceAnalyticsEvent, properties: HealthIntelligenceAnalyticsProperties) {
        #if DEBUG
        HealthIntelligenceAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum HealthIntelligenceAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(
        subsystem: "FitPilot",
        category: "HealthIntelligenceAnalytics"
    )

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_HEALTH_INTELLIGENCE_ANALYTICS_TRACE"] != "0"
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[HealthIntelligenceAnalytics] \(message)"
            : "[HealthIntelligenceAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
