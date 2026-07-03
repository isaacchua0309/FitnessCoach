//
//  TodayMacroBalanceFormatting.swift
//  Fitness Coach
//
//  Legacy typealiases — prefer TodayNutritionProgressFormatting.
//

import Foundation

typealias TodayMacroBalanceDisplayState = TodayNutritionDisplayState

typealias TodayMacroBalanceRowDisplayModel = TodayNutritionProgressRowDisplayModel

struct TodayMacroBalanceCardDisplayModel: Equatable {
    var protein: TodayMacroBalanceRowDisplayModel
    var carbs: TodayMacroBalanceRowDisplayModel
    var fat: TodayMacroBalanceRowDisplayModel
    var accessibilitySummary: String
}

enum TodayMacroBalanceFormatting {

    static let nearTargetRemainingRatio = TodayNutritionProgressFormatting.nearTargetRemainingRatio
    static let nearTargetRemainingGrams = TodayNutritionProgressFormatting.nearTargetRemainingGrams

    static func displayModel(for macros: MacroSummary) -> TodayMacroBalanceCardDisplayModel {
        let display = TodayNutritionProgressFormatting.displayModel(
            macros: macros,
            water: WaterSummary(consumedMl: 0, targetMl: 0, remainingMl: 0, progress: 0),
            calorieSummary: CalorieSummary(
                consumed: 0,
                target: 1,
                remaining: 0,
                progress: 0,
                isOverTarget: false
            )
        )

        return TodayMacroBalanceCardDisplayModel(
            protein: display.rows[0],
            carbs: display.rows[1],
            fat: display.rows[2],
            accessibilitySummary: display.accessibilitySummary
        )
    }

    static func rowDisplayModel(
        name: String,
        progress: MacroProgress,
        isProteinPriority: Bool
    ) -> TodayMacroBalanceRowDisplayModel {
        TodayNutritionProgressFormatting.macroRow(
            name: name,
            progress: progress,
            emphasis: isProteinPriority ? .primary : .secondary
        )
    }

    static func displayState(for progress: MacroProgress) -> TodayMacroBalanceDisplayState {
        TodayNutritionProgressFormatting.displayState(
            consumed: progress.consumed,
            target: progress.target,
            remaining: progress.remaining
        )
    }

    static func ratioText(consumed: Double, target: Double) -> String {
        TodayNutritionProgressFormatting.macroRatioText(consumed: consumed, target: target)
    }

    static func remainingText(
        for progress: MacroProgress,
        state: TodayMacroBalanceDisplayState
    ) -> String {
        TodayNutritionProgressFormatting.macroRemainingText(
            consumed: progress.consumed,
            target: progress.target,
            state: state
        )
    }

    static func barProgress(for progress: MacroProgress) -> Double {
        TodayNutritionProgressFormatting.barProgress(
            consumed: progress.consumed,
            target: progress.target
        )
    }

    static func effectiveRemaining(_ progress: MacroProgress) -> Double {
        progress.target - progress.consumed
    }

    static func accessibilityValue(
        ratioText: String,
        remainingText: String,
        barProgress: Double,
        state: TodayMacroBalanceDisplayState
    ) -> String {
        TodayNutritionProgressFormatting.accessibilityValue(
            ratioText: ratioText,
            remainingText: remainingText,
            barProgress: barProgress,
            state: state
        )
    }
}
