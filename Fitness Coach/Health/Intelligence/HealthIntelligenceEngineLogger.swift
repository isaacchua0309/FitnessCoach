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

    static func snapshotCompositionCompleted(
        dayKey: String,
        mode: String,
        dataGapCount: Int,
        recoveryStatus: String,
        hasWorkout: Bool,
        durationMs: Int
    ) {
        log(
            level: "info",
            message: "Health intelligence snapshot composed",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "dataGapCount": String(dataGapCount),
                "recoveryStatus": recoveryStatus,
                "hasWorkout": String(hasWorkout),
                "durationMs": String(durationMs)
            ]
        )
    }

    static func engineFallback(
        section: HealthIntelligenceEngineSection,
        reason: String,
        fields: [String: String] = [:]
    ) {
        var merged = fields
        merged["section"] = section.rawValue
        merged["fallbackReason"] = reason
        log(level: "warn", message: "Health intelligence engine fallback", fields: merged)
    }

    #if DEBUG
    static func snapshotComposed(
        dayKey: String,
        recoveryStatus: String,
        hasWorkout: Bool,
        activitySteps: String?,
        nutritionShouldChange: Bool,
        nextBestActionID: String,
        planConfidence: String,
        hasWeeklyReview: Bool
    ) {
        var fields: [String: String] = [
            "dayKey": dayKey,
            "recoveryStatus": recoveryStatus,
            "hasWorkout": String(hasWorkout),
            "nutritionShouldChange": String(nutritionShouldChange),
            "nextBestActionID": nextBestActionID,
            "planConfidence": planConfidence,
            "hasWeeklyReview": String(hasWeeklyReview)
        ]
        if let activitySteps {
            fields["activitySteps"] = activitySteps
        }
        log(level: "info", message: "Health intelligence snapshot composed", fields: fields)
    }

    static func snapshotVerification(dayKey: String, fields: [String: String]) {
        var merged = fields
        merged["dayKey"] = dayKey
        log(level: "info", message: "Health intelligence snapshot verification", fields: merged)
    }

    static func wiringRegistered(fields: [String: String]) {
        log(level: "info", message: "Health intelligence engines wired", fields: fields)
    }
    #endif

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthIntelligenceEngine")

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level

        #if DEBUG
        print("[HealthIntelligenceEngine] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }
}
