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
    var statusLine: String
    var progress: Double
    var isOverTarget: Bool
    var showsLogMealCTA: Bool
    var accessibilityLabel: String
}

enum TodayMissionHeroFormatter {

    /// Remaining calories at or below this share of the daily target count as “near target”.
    static let nearTargetRemainingRatio = 0.15

    static func displayModel(
        calorieSummary: CalorieSummary,
        proteinProgress: MacroProgress,
        mealsEmptyKind: TodayMealsEmptyKind
    ) -> TodayMissionHeroDisplayModel {
        let statusLine = TodayEmptyStateFormatting.missionStatusLine(
            mealsEmptyKind: mealsEmptyKind,
            calorieSummary: calorieSummary,
            proteinProgress: proteinProgress
        )

        return TodayMissionHeroDisplayModel(
            primaryMetricLabel: calorieSummary.isOverTarget
                ? FormaProductCopy.Today.Mission.caloriesOverLabel
                : FormaProductCopy.Today.Mission.caloriesRemainingLabel,
            primaryMetricValue: TodayMissionHeroFormatting.primaryMetricValue(calorieSummary: calorieSummary),
            statusLine: statusLine,
            progress: min(max(calorieSummary.progress, 0), 1),
            isOverTarget: calorieSummary.isOverTarget,
            showsLogMealCTA: TodayEmptyStateFormatting.missionShowsLogCTA(mealsEmptyKind: mealsEmptyKind),
            accessibilityLabel: accessibilityLabel(
                primaryMetricLabel: calorieSummary.isOverTarget
                    ? FormaProductCopy.Today.Mission.caloriesOverLabel
                    : FormaProductCopy.Today.Mission.caloriesRemainingLabel,
                primaryMetricValue: TodayMissionHeroFormatting.primaryMetricValue(calorieSummary: calorieSummary),
                statusLine: statusLine
            )
        )
    }

    static func displayModel(
        mission: TodayMissionState,
        proteinProgress: MacroProgress,
        mealsEmptyKind: TodayMealsEmptyKind
    ) -> TodayMissionHeroDisplayModel {
        displayModel(
            calorieSummary: mission.calorieSummary,
            proteinProgress: proteinProgress,
            mealsEmptyKind: mealsEmptyKind
        )
    }

    static func isNearTarget(_ summary: CalorieSummary) -> Bool {
        guard !summary.isOverTarget, summary.target > 0 else { return false }
        let remainingRatio = Double(max(summary.remaining, 0)) / Double(summary.target)
        return remainingRatio <= nearTargetRemainingRatio && summary.consumed > 0
    }

    private static func accessibilityLabel(
        primaryMetricLabel: String,
        primaryMetricValue: String,
        statusLine: String
    ) -> String {
        [
            FormaProductCopy.Today.Mission.sectionTitle,
            "\(primaryMetricLabel), \(primaryMetricValue)",
            statusLine
        ].joined(separator: ". ")
    }
}
