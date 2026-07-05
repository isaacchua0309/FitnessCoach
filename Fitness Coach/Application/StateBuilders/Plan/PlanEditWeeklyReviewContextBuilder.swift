//
//  PlanEditWeeklyReviewContextBuilder.swift
//  Fitness Coach
//
//  Forma — Weekly review context for safe Plan edit entry (display only).
//

import Foundation

struct PlanEditWeeklyReviewContext: Equatable, Sendable {
    let title: String
    let message: String
    let formulaMaintenanceKcal: Int?
    let learnedMaintenanceKcal: Int?
    let currentCalorieTargetKcal: Int
    let suggestedCalorieDelta: Int?
    let suggestedTargetKcal: Int?
    let confidenceLabel: String?
    let caveats: [String]
    let safetyCopy: String
    let accessibilitySummary: String
}

enum PlanEditWeeklyReviewContextBuilder {

    static func build(from dashboard: PlanDashboardState) -> PlanEditWeeklyReviewContext {
        let weekly = dashboard.weeklyRecommendation
        let profile = dashboard.profile
        let currentTarget = profile.targets.calorieTarget

        var caveats: [String] = []
        if !weekly.showsLearnedEstimate {
            caveats.append(weekly.learnedMaintenanceUnavailableCopy)
        }
        if weekly.showsRecommendation, let message = weekly.recommendationMessage {
            caveats.append(message)
        }
        caveats.append(weekly.safetyCopy)

        let title = weekly.recommendationTitle
            ?? FormaProductCopy.PlanEditWeeklyReview.defaultTitle
        let message = weekly.recommendationMessage
            ?? FormaProductCopy.PlanEditWeeklyReview.defaultMessage

        let context = PlanEditWeeklyReviewContext(
            title: title,
            message: message,
            formulaMaintenanceKcal: weekly.formulaMaintenanceKcal,
            learnedMaintenanceKcal: weekly.learnedMaintenanceKcal,
            currentCalorieTargetKcal: currentTarget,
            suggestedCalorieDelta: weekly.suggestedCalorieDelta,
            suggestedTargetKcal: weekly.suggestedTargetKcal,
            confidenceLabel: weekly.confidenceLabel,
            caveats: orderedUnique(caveats),
            safetyCopy: weekly.safetyCopy,
            accessibilitySummary: ""
        )

        return PlanEditWeeklyReviewContext(
            title: context.title,
            message: context.message,
            formulaMaintenanceKcal: context.formulaMaintenanceKcal,
            learnedMaintenanceKcal: context.learnedMaintenanceKcal,
            currentCalorieTargetKcal: context.currentCalorieTargetKcal,
            suggestedCalorieDelta: context.suggestedCalorieDelta,
            suggestedTargetKcal: context.suggestedTargetKcal,
            confidenceLabel: context.confidenceLabel,
            caveats: context.caveats,
            safetyCopy: context.safetyCopy,
            accessibilitySummary: accessibilitySummary(for: context)
        )
    }

    private static func accessibilitySummary(for context: PlanEditWeeklyReviewContext) -> String {
        var parts = [context.title, context.message]

        if let formula = context.formulaMaintenanceKcal {
            parts.append(
                "\(FormaProductCopy.PlanMissionControl.formulaMaintenanceLabel): \(formula) kilocalories per day"
            )
        }
        if let learned = context.learnedMaintenanceKcal {
            parts.append(
                "\(FormaProductCopy.PlanMissionControl.learnedMaintenanceLabel): \(learned) kilocalories per day"
            )
        }

        parts.append("Current target: \(context.currentCalorieTargetKcal) kilocalories per day")

        if let delta = context.suggestedCalorieDelta, let target = context.suggestedTargetKcal {
            let sign = delta > 0 ? "+" : ""
            parts.append("Suggested change \(sign)\(delta) to \(target) kilocalories per day")
        }

        if let confidence = context.confidenceLabel {
            parts.append(confidence)
        }

        parts.append(contentsOf: context.caveats)
        return parts.joined(separator: ". ")
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard seen.insert(trimmed).inserted else { continue }
            ordered.append(trimmed)
        }
        return ordered
    }
}
