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
        PublicEntryAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum PublicEntryAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "PublicEntryAnalytics")

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_PUBLIC_ENTRY_ANALYTICS_TRACE"] != "0"
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[PublicEntryAnalytics] \(message)"
            : "[PublicEntryAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
