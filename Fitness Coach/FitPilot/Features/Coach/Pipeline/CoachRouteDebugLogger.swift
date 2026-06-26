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
            source=\(decision.routeSource.rawValue, privacy: .public) \
            intent=\(decision.intent?.rawValue ?? "none", privacy: .public) \
            tier=\(decision.modelTier?.rawValue ?? "none", privacy: .public) \
            handler=\(decision.chosenHandler, privacy: .public) \
            requiresAPI=\(decision.requiresAPI, privacy: .public) \
            reason=\(decision.reason ?? "none", privacy: .public)
            """
        )
    }

    static func logMessage(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}
