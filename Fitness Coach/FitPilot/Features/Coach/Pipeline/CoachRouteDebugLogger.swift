//
//  CoachRouteDebugLogger.swift
//  Fitness Coach
//
//  FitPilot AI — debug telemetry for Coach route decisions.
//

import Foundation
import OSLog

enum CoachRouteDebugLogger {
    private static let logger = Logger(subsystem: "FitPilot", category: "CoachRouting")

    static func log(_ decision: CoachRouteDecision) {
        logger.debug(
            """
            raw=\(decision.rawMessage, privacy: .private) \
            normalized=\(decision.normalizedMessage, privacy: .private) \
            intent=\(decision.detectedIntent.rawValue, privacy: .public) \
            confidence=\(decision.confidence, privacy: .public) \
            handler=\(decision.chosenHandler, privacy: .public) \
            fallback=\(decision.fallbackReason ?? "none", privacy: .public)
            """
        )
    }
}
