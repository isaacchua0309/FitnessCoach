//
//  CoachHealthIntelligenceContext.swift
//  Fitness Coach
//
//  Forma — Coach-safe Health Intelligence summary for AI prompt injection.
//  No raw HealthKit samples, HRV/RHR values, or sensitive metric details.
//

import Foundation

struct CoachHealthIntelligenceContext: Equatable, Sendable, Codable {
    let date: Date
    let healthContextStatus: CoachHealthContextStatus
    let availableSignals: [String]
    let missingSignals: [String]
    let lastHealthSyncAt: Date?
    let healthContextInstruction: String
    let recoveryStatus: String
    let recoveryScore: Int?
    let recoveryConfidence: String
    let recoveryExplanation: String
    let workoutCompletedToday: Bool
    let workoutSummaryText: String?
    let workoutDemand: String?
    let totalWorkoutMinutesToday: Int
    let totalActiveCaloriesToday: Int?
    let stepsToday: Int?
    let adaptiveNutritionAdvice: String?
    let proteinRecommendation: Int?
    let hydrationRecommendationMl: Int?
    let trainingLoadStatus: String
    let nextBestActionTitle: String?
    let nextBestActionReason: String?
    let healthDataConfidenceLabel: String

    func toPromptContext(calendar: Calendar = .current) -> String {
        var lines: [String] = []

        lines.append("Health intelligence for \(Self.formatDate(date, calendar: calendar)):")
        lines.append("Health context status: \(healthContextStatus.rawValue).")
        lines.append(availableSignalsLine)
        lines.append(missingSignalsLine)
        lines.append(lastHealthSyncLine(calendar: calendar))
        lines.append("Instruction: \(healthContextInstruction)")
        lines.append(recoveryLine)
        lines.append(workoutLine)
        lines.append(activityLine)
        lines.append("Training load: \(trainingLoadStatus).")
        lines.append(nutritionLine)
        lines.append(nextActionLine)
        lines.append("Data confidence: \(healthDataConfidenceLabel).")

        return lines.joined(separator: "\n")
    }

    // MARK: - Prompt lines

    private var availableSignalsLine: String {
        if availableSignals.isEmpty {
            return "Available signals: none."
        }
        return "Available signals: \(availableSignals.joined(separator: ", "))."
    }

    private var missingSignalsLine: String {
        if missingSignals.isEmpty {
            return "Missing signals: none reported."
        }
        return "Missing signals: \(missingSignals.joined(separator: ", "))."
    }

    private func lastHealthSyncLine(calendar: Calendar) -> String {
        guard let lastHealthSyncAt else {
            return "Last health sync: unavailable."
        }
        return "Last health sync: \(Self.formatTimestamp(lastHealthSyncAt, calendar: calendar))."
    }

    private var recoveryLine: String {
        guard hasRecoverySignal else {
            return "Recovery data: unavailable."
        }

        var parts = ["Recovery: \(recoveryStatus) (\(recoveryConfidence) confidence)."]

        if let scoreLine = recoveryScoreLine {
            parts.append(scoreLine)
        }

        parts.append(recoveryExplanation)
        return parts.joined(separator: " ")
    }

    private var recoveryScoreLine: String? {
        guard let recoveryScore else { return nil }
        guard recoveryConfidence == RecoveryConfidence.moderate.rawValue
            || recoveryConfidence == RecoveryConfidence.high.rawValue else {
            return nil
        }
        return "Estimated recovery score: \(recoveryScore)."
    }

    private var workoutLine: String {
        guard hasWorkoutSignal else {
            return "Workout data: unavailable."
        }

        guard workoutCompletedToday else {
            return "Workout data: no synced workout today."
        }

        var parts = ["Workout: completed"]
        if let workoutSummaryText, !workoutSummaryText.isEmpty {
            parts.append("— \(workoutSummaryText)")
        }
        if totalWorkoutMinutesToday > 0 {
            parts.append("(\(totalWorkoutMinutesToday) min)")
        }
        if let workoutDemand, workoutDemand != WorkoutDemand.unknown.rawValue {
            parts.append("Demand: \(workoutDemand).")
        }
        return parts.joined(separator: " ")
    }

    private var activityLine: String {
        guard hasStepsSignal else {
            return "Steps data: unavailable."
        }

        guard let stepsToday else {
            return "Steps data: unavailable."
        }

        return "Activity: \(stepsToday.formatted()) steps."
    }

    private var nutritionLine: String {
        var parts: [String] = []

        if let adaptiveNutritionAdvice, !adaptiveNutritionAdvice.isEmpty {
            parts.append(adaptiveNutritionAdvice)
        } else {
            parts.append("Nutrition guidance unavailable.")
        }

        if let proteinRecommendation {
            parts.append("Protein recommendation: \(proteinRecommendation)g.")
        }

        if let hydrationRecommendationMl, hydrationRecommendationMl > 0 {
            parts.append("Hydration recommendation: \(hydrationRecommendationMl)ml extra today.")
        }

        return parts.joined(separator: " ")
    }

    private var nextActionLine: String {
        guard let nextBestActionTitle, !nextBestActionTitle.isEmpty else {
            return "Next best action: none."
        }

        if let nextBestActionReason, !nextBestActionReason.isEmpty {
            return "Next best action: \(nextBestActionTitle) (\(Self.humanizedReason(nextBestActionReason)))."
        }

        return "Next best action: \(nextBestActionTitle)."
    }

    private var hasRecoverySignal: Bool {
        healthContextStatus != .unavailable
            && (availableSignals.contains("sleep")
                || availableSignals.contains("HRV")
                || availableSignals.contains("resting heart rate")
                || availableSignals.contains("recovery baseline")
                || recoveryStatus != RecoveryStatus.unknown.rawValue)
    }

    private var hasWorkoutSignal: Bool {
        availableSignals.contains("workouts")
    }

    private var hasStepsSignal: Bool {
        availableSignals.contains("steps")
    }

    // MARK: - Formatting

    private static func formatDate(_ date: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }

    private static func formatTimestamp(_ date: Date, calendar: Calendar) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private static func humanizedReason(_ reason: String) -> String {
        reason
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .lowercased()
    }
}

extension CoachHealthIntelligenceContext {

    static func unavailable(
        for date: Date = Date(),
        lastHealthSyncAt: Date? = nil,
        status: CoachHealthContextStatus = .unavailable,
        missingSignals: [String] = ["health data"]
    ) -> CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContext(
            date: date,
            healthContextStatus: status,
            availableSignals: [],
            missingSignals: missingSignals,
            lastHealthSyncAt: lastHealthSyncAt,
            healthContextInstruction: CoachHealthContextInstruction.doNotAssumeMissingData,
            recoveryStatus: RecoveryStatus.unknown.rawValue,
            recoveryScore: nil,
            recoveryConfidence: "limited",
            recoveryExplanation: "Recovery data is unavailable.",
            workoutCompletedToday: false,
            workoutSummaryText: nil,
            workoutDemand: nil,
            totalWorkoutMinutesToday: 0,
            totalActiveCaloriesToday: nil,
            stepsToday: nil,
            adaptiveNutritionAdvice: nil,
            proteinRecommendation: nil,
            hydrationRecommendationMl: nil,
            trainingLoadStatus: "unknown",
            nextBestActionTitle: nil,
            nextBestActionReason: nil,
            healthDataConfidenceLabel: FormaProductCopy.HealthIntelligence.limitedEstimateLabel
        )
    }
}
