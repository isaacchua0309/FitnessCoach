//
//  HealthIntelligenceEngineLogger.swift
//  Fitness Coach
//
//  Forma — Safe debug logging for Health Intelligence snapshot composition.
//

import Foundation
import os

enum HealthIntelligenceEngineSection: String, Sendable {
    case context
    case trainingLoad
    case workout
    case recovery
    case activity
    case adaptiveNutrition
    case nextBestAction
    case weeklyReview
    case planConfidence
}

enum HealthIntelligenceEngineLogger {

    static func event(_ message: String, fields: [String: String] = [:]) {
        log(level: "info", message: message, fields: fields)
    }

    static func sectionDegraded(
        _ section: HealthIntelligenceEngineSection,
        fields: [String: String] = [:]
    ) {
        var merged = fields
        merged["section"] = section.rawValue
        log(level: "warn", message: "Health intelligence section degraded", fields: merged)
    }

    static func sectionFailure(
        _ section: HealthIntelligenceEngineSection,
        error: Error,
        fields: [String: String] = [:]
    ) {
        var merged = fields
        merged["section"] = section.rawValue
        merged["errorDomain"] = (error as NSError).domain
        merged["errorCode"] = String((error as NSError).code)
        let description = error.localizedDescription
        if !description.isEmpty {
            merged["errorDescription"] = description
        }
        log(level: "warn", message: "Health intelligence section failed", fields: merged)
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthIntelligenceEngine")

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level

        #if DEBUG
        print("[HealthIntelligenceEngine] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(message, privacy: .public)")
    }
}
