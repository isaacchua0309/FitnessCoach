//
//  TodayMissionHeroFormatting.swift
//  Fitness Coach
//
//  Forma — Display formatting for Today's Mission hero.
//

import Foundation

enum TodayMissionHeroFormatting {

    private static let calorieFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func calories(_ value: Int) -> String {
        calorieFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func proteinGrams(_ value: Double) -> String {
        FoodEntryFormFormatter.formatMacro(max(value, 0))
    }

    static func primaryMetricValue(calorieSummary: CalorieSummary) -> String {
        if calorieSummary.isOverTarget {
            let overBy = max(calorieSummary.consumed - calorieSummary.target, 0)
            return "\(calories(overBy)) \(FormaProductCopy.Today.Mission.overSuffix)"
        }
        return "\(calories(max(calorieSummary.remaining, 0))) \(FormaProductCopy.Today.Mission.remainingSuffix)"
    }
}

struct TodayMissionHeroDisplayModel: Equatable {
    var primaryMetricLabel: String
    var primaryMetricValue: String
    var goalLine: String
    var consumedLine: String
    var proteinLine: String
    var statusLine: String
    var progress: Double
    var isOverTarget: Bool
    var accessibilityLabel: String
}

enum TodayMissionHeroFormatter {

    /// Remaining calories at or below this share of the daily target count as “near target”.
    static let nearTargetRemainingRatio = 0.15

    static func displayModel(
        mission: TodayMissionState,
        proteinProgress: MacroProgress,
        mealsEmpty: Bool
    ) -> TodayMissionHeroDisplayModel {
        let calories = mission.calorieSummary
        let statusLine = statusLine(
            calorieSummary: calories,
            proteinProgress: proteinProgress,
            mealsEmpty: mealsEmpty
        )
        let proteinLine = proteinSubMetricLine(for: proteinProgress)

        return TodayMissionHeroDisplayModel(
            primaryMetricLabel: calories.isOverTarget
                ? FormaProductCopy.Today.Mission.caloriesOverLabel
                : FormaProductCopy.Today.Mission.caloriesRemainingLabel,
            primaryMetricValue: TodayMissionHeroFormatting.primaryMetricValue(calorieSummary: calories),
            goalLine: goalLine(calories.target),
            consumedLine: consumedLine(calories.consumed),
            proteinLine: proteinLine,
            statusLine: statusLine,
            progress: min(max(calories.progress, 0), 1),
            isOverTarget: calories.isOverTarget,
            accessibilityLabel: accessibilityLabel(
                primaryMetricLabel: calories.isOverTarget
                    ? FormaProductCopy.Today.Mission.caloriesOverLabel
                    : FormaProductCopy.Today.Mission.caloriesRemainingLabel,
                primaryMetricValue: TodayMissionHeroFormatting.primaryMetricValue(calorieSummary: calories),
                goalLine: goalLine(calories.target),
                consumedLine: consumedLine(calories.consumed),
                proteinLine: proteinLine,
                statusLine: statusLine
            )
        )
    }

    static func goalLine(_ targetKcal: Int) -> String {
        "Goal: \(TodayMissionHeroFormatting.calories(targetKcal)) kcal"
    }

    static func consumedLine(_ consumedKcal: Int) -> String {
        "Consumed: \(TodayMissionHeroFormatting.calories(consumedKcal)) kcal"
    }

    static func proteinRemainingLine(_ grams: Double) -> String {
        "Protein remaining: \(TodayMissionHeroFormatting.proteinGrams(grams))g"
    }

    static func statusLine(
        calorieSummary: CalorieSummary,
        proteinProgress: MacroProgress,
        mealsEmpty: Bool
    ) -> String {
        if mealsEmpty {
            return FormaProductCopy.Today.Mission.statusStartFirstMeal
        }
        if calorieSummary.isOverTarget {
            return FormaProductCopy.Today.Mission.statusOverTarget
        }
        if proteinProgress.progress < TodayFocusBuilder.proteinOnTrackThreshold {
            return FormaProductCopy.Today.Mission.statusProteinGap
        }
        if isNearTarget(calorieSummary) {
            return FormaProductCopy.Today.Mission.statusNearTarget
        }
        return FormaProductCopy.Today.Mission.statusOnTrack
    }

    static func isNearTarget(_ summary: CalorieSummary) -> Bool {
        guard !summary.isOverTarget, summary.target > 0 else { return false }
        let remainingRatio = Double(max(summary.remaining, 0)) / Double(summary.target)
        return remainingRatio <= nearTargetRemainingRatio && summary.consumed > 0
    }

    static func proteinSubMetricLine(for proteinProgress: MacroProgress) -> String {
        if proteinProgress.progress >= TodayFocusBuilder.proteinOnTrackThreshold {
            return FormaProductCopy.Today.Mission.proteinOnTrack
        }
        return proteinRemainingLine(proteinProgress.remaining)
    }

    private static func accessibilityLabel(
        primaryMetricLabel: String,
        primaryMetricValue: String,
        goalLine: String,
        consumedLine: String,
        proteinLine: String,
        statusLine: String
    ) -> String {
        [
            FormaProductCopy.Today.Mission.sectionTitle,
            "\(primaryMetricLabel), \(primaryMetricValue)",
            goalLine,
            consumedLine,
            proteinLine,
            statusLine
        ].joined(separator: ". ")
    }
}
