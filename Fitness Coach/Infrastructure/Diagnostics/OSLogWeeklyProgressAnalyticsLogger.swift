//
//  OSLogWeeklyProgressAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for Weekly Progress Loop analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogWeeklyProgressAnalyticsLogger: WeeklyProgressAnalyticsLogging {

    func log(_ event: WeeklyProgressAnalyticsEvent, properties: WeeklyProgressAnalyticsProperties) {
        #if DEBUG
        WeeklyProgressAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum WeeklyProgressAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(
        subsystem: "FitPilot",
        category: "WeeklyProgressAnalytics"
    )

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.weeklyProgressAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[WeeklyProgressAnalytics] \(message)"
            : "[WeeklyProgressAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
