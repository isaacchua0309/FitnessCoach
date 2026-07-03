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
    let missingSignals: [String]
    let healthDataConfidenceLabel: String

    func toPromptContext(calendar: Calendar = .current) -> String {
        var lines: [String] = []

        lines.append("Health intelligence for \(Self.formatDate(date, calendar: calendar)):")
        lines.append(recoveryLine)
        lines.append(workoutLine)
        lines.append(activityLine)
        lines.append("Training load: \(trainingLoadStatus).")
        lines.append(nutritionLine)
        lines.append(nextActionLine)
        lines.append(missingSignalsLine)
        lines.append("Data confidence: \(healthDataConfidenceLabel).")

        return lines.joined(separator: "\n")
    }

    // MARK: - Prompt lines

    private var recoveryLine: String {
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
        guard workoutCompletedToday else {
            return "Workout: none logged today."
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
        guard let stepsToday else {
            return "Activity: unavailable."
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

    private var missingSignalsLine: String {
        if missingSignals.isEmpty {
            return "Missing signals: none reported."
        }
        return "Missing signals: \(missingSignals.joined(separator: ", "))."
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

    private static func humanizedReason(_ reason: String) -> String {
        reason
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .lowercased()
    }
}

extension CoachHealthIntelligenceContext {

    static func unavailable(for date: Date = Date()) -> CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligenceSnapshot(
                date: date,
                recovery: .unknown,
                workout: nil,
                activity: .empty,
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: .unknown,
                nextBestAction: .none
            )
        )
    }
}
