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
        OnboardingAnalyticsDebugLogger.event(event.rawValue, fields: properties.privacySafeParameters())
        #endif
    }
}

#if DEBUG
enum OnboardingAnalyticsDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "OnboardingAnalytics")

    nonisolated static var isEnabled: Bool { FormaAbTest.Diagnostics.onboardingAnalyticsTrace }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }
        LogRedactor.emitOSLogTrace(
            prefix: "OnboardingAnalytics",
            logger: logger,
            message: message,
            fields: fields
        )
    }
}
#endif
