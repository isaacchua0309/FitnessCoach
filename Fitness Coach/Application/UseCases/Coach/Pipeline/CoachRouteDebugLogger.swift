//
//  CoachRouteDebugLogger.swift
//  Fitness Coach
//
//  FitPilot AI — debug telemetry for Coach route decisions.
//

import Foundation

enum CoachRouteDebugLogger {

    static func log(_ decision: CoachRouteDecision, intentResult: CoachIntentResult? = nil) {
        CoachAccuracyObservabilityLogger.logRoute(
            decision: decision,
            intentResult: intentResult
        )

        #if DEBUG
        FormaPipelineTracer.event(
            stage: .routeDecision,
            level: .debug,
            message: "Route decision",
            fields: [
                "normalizedLength": String(decision.normalizedMessage.count),
                "source": decision.routeSource.rawValue,
                "intent": decision.intent?.rawValue ?? "none",
                "tier": decision.modelTier?.rawValue ?? "none",
                "handler": decision.chosenHandler,
                "requiresAPI": String(decision.requiresAPI),
                "reason": decision.reason ?? "none",
                "classifierConfidence": intentResult.map { String(format: "%.2f", $0.confidence) } ?? "none"
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
