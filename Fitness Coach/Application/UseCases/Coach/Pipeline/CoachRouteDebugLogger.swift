//
//  CoachRouteDebugLogger.swift
//  Fitness Coach
//
//  FitPilot AI — debug telemetry for Coach route decisions.
//

import Foundation

enum CoachRouteDebugLogger {

    static func log(_ decision: CoachRouteDecision) {
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .routeDecision,
            level: .debug,
            message: "Route decision",
            fields: [
                "raw": decision.rawMessage,
                "normalized": decision.normalizedMessage,
                "source": decision.routeSource.rawValue,
                "intent": decision.intent?.rawValue ?? "none",
                "tier": decision.modelTier?.rawValue ?? "none",
                "handler": decision.chosenHandler,
                "requiresAPI": String(decision.requiresAPI),
                "reason": decision.reason ?? "none"
            ]
        )
        #endif
    }

    static func logMessage(_ message: String) {
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .classify,
            level: .debug,
            message: message
        )
        #endif
    }
}
