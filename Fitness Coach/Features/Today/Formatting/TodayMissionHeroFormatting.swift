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
}

enum TodayMissionPrimaryKind: Equatable, Sendable {
    case remaining
    case over
    case targetReached
    case missingTarget
}

struct TodayMissionHeroDisplayModel: Equatable {
    var primaryKind: TodayMissionPrimaryKind
    var primaryValue: String
    var goalLine: String
    var consumedLine: String
    var proteinRemainingLine: String
    var statusLine: String
    var showsLogMealCTA: Bool
    var accessibilityLabel: String

    var isOverTarget: Bool { primaryKind == .over }
}

enum TodayMissionHeroFormatter {

    /// Remaining calories at or below this share of the daily target count as “near target”.
    static let nearTargetRemainingRatio = 0.15

    static func displayModel(
        calorieSummary: CalorieSummary,
        proteinProgress: MacroProgress,
        mealsEmptyKind: TodayMealsEmptyKind
    ) -> TodayMissionHeroDisplayModel {
        let primaryKind = primaryKind(for: calorieSummary)
        let primaryValue = primaryValue(for: calorieSummary, kind: primaryKind)
        let goalLine = goalLine(for: calorieSummary)
        let consumedLine = consumedLine(for: calorieSummary)
        let proteinRemainingLine = proteinRemainingLine(for: proteinProgress)
        let statusLine = statusLine(
            mealsEmptyKind: mealsEmptyKind,
            calorieSummary: calorieSummary,
            primaryKind: primaryKind
        )
        let showsLogMealCTA = mealsEmptyKind != .hasMeals

        return TodayMissionHeroDisplayModel(
            primaryKind: primaryKind,
            primaryValue: primaryValue,
            goalLine: goalLine,
            consumedLine: consumedLine,
            proteinRemainingLine: proteinRemainingLine,
            statusLine: statusLine,
            showsLogMealCTA: showsLogMealCTA,
            accessibilityLabel: accessibilityLabel(
                primaryValue: primaryValue,
                goalLine: goalLine,
                consumedLine: consumedLine,
                proteinRemainingLine: proteinRemainingLine,
                statusLine: statusLine
            )
        )
    }

    static func isNearTarget(_ summary: CalorieSummary) -> Bool {
        guard !summary.isOverTarget, summary.target > 0 else { return false }
        let remainingRatio = Double(max(summary.remaining, 0)) / Double(summary.target)
        return remainingRatio <= nearTargetRemainingRatio && summary.consumed > 0
    }

    static func isTargetReached(_ summary: CalorieSummary) -> Bool {
        guard summary.target > 0, summary.consumed > 0, !summary.isOverTarget else {
            return false
        }
        return isNearTarget(summary) || summary.remaining <= 0
    }

    static func primaryKind(for summary: CalorieSummary) -> TodayMissionPrimaryKind {
        guard summary.target > 0 else { return .missingTarget }
        if summary.isOverTarget { return .over }
        if isTargetReached(summary) { return .targetReached }
        return .remaining
    }

    static func primaryValue(
        for summary: CalorieSummary,
        kind: TodayMissionPrimaryKind
    ) -> String {
        switch kind {
        case .remaining:
            return FormaProductCopy.Today.Mission.primaryRemaining(max(summary.remaining, 0))
        case .over:
            let overBy = max(summary.consumed - summary.target, 0)
            return FormaProductCopy.Today.Mission.primaryOver(overBy)
        case .targetReached:
            return FormaProductCopy.Today.Mission.targetReachedPrimary
        case .missingTarget:
            return FormaProductCopy.Today.Mission.missingCalorieTarget
        }
    }

    static func goalLine(for summary: CalorieSummary) -> String {
        guard summary.target > 0 else {
            return FormaProductCopy.Today.Mission.missingCalorieTarget
        }
        return FormaProductCopy.Today.Mission.goalLine(targetKcal: summary.target)
    }

    static func consumedLine(for summary: CalorieSummary) -> String {
        FormaProductCopy.Today.Mission.consumedLine(consumedKcal: summary.consumed)
    }

    static func proteinRemainingLine(for protein: MacroProgress) -> String {
        if protein.target > 0, protein.progress >= TodayFocusBuilder.proteinOnTrackThreshold {
            return FormaProductCopy.Today.Mission.proteinOnTrack
        }
        return FormaProductCopy.Today.Mission.proteinRemainingLine(grams: protein.remaining)
    }

    static func statusLine(
        mealsEmptyKind: TodayMealsEmptyKind,
        calorieSummary: CalorieSummary,
        primaryKind: TodayMissionPrimaryKind
    ) -> String {
        switch mealsEmptyKind {
        case .newProfileNoMeals, .newDayNoMeals:
            return FormaProductCopy.Today.Mission.statusPlanReady
        case .hasMeals:
            break
        }

        switch primaryKind {
        case .over:
            return FormaProductCopy.Today.Mission.statusOverTarget
        case .targetReached:
            return FormaProductCopy.Today.Mission.statusTargetReached
        case .remaining, .missingTarget:
            return ""
        }
    }

    private static func accessibilityLabel(
        primaryValue: String,
        goalLine: String,
        consumedLine: String,
        proteinRemainingLine: String,
        statusLine: String
    ) -> String {
        var parts = [
            FormaProductCopy.Today.Mission.sectionTitle,
            primaryValue,
            goalLine,
            consumedLine,
            proteinRemainingLine
        ]
        if !statusLine.isEmpty {
            parts.append(statusLine)
        }
        return parts.joined(separator: ". ")
    }
}
