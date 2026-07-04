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

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.healthIntelligenceAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "HealthIntelligenceAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
