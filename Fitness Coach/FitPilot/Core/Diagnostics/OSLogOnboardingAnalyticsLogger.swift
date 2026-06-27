//
//  OSLogOnboardingAnalyticsLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG OSLog sink for onboarding analytics events.
//

import Foundation

#if DEBUG
import OSLog
#endif

struct OSLogOnboardingAnalyticsLogger: OnboardingAnalyticsLogging {

    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {
        #if DEBUG
        OnboardingAnalyticsDebugLogger.event(event.rawValue, fields: properties.asParameters())
        #endif
    }
}

#if DEBUG
enum OnboardingAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "OnboardingAnalytics")

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_ONBOARDING_ANALYTICS_TRACE"] != "0"
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[OnboardingAnalytics] \(message)"
            : "[OnboardingAnalytics] \(message) \(fieldLine)"
        logger.info("\(line, privacy: .public)")
    }
}
#endif
