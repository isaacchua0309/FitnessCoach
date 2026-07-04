//
//  OSLogPlanAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Plan analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogPlanAnalyticsLogger: PlanAnalyticsLogging {

    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties) {
        #if DEBUG
        PlanAnalyticsDebugLogger.event(event.rawValue, fields: properties.privacySafeParameters())
        #endif
    }
}

#if DEBUG
enum PlanAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "PlanAnalytics")

    nonisolated static var isEnabled: Bool { true }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "PlanAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
