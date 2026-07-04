//
//  OSLogPublicEntryAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for public entry analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogPublicEntryAnalyticsLogger: PublicEntryAnalyticsLogging {

    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties) {
        #if DEBUG
        PublicEntryAnalyticsDebugLogger.event(event.rawValue, fields: properties.privacySafeParameters())
        #endif
    }
}

#if DEBUG
enum PublicEntryAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "PublicEntryAnalytics")

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.publicEntryAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "PublicEntryAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
