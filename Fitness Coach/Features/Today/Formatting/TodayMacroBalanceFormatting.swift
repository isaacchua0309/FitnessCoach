//
//  TodayMacroBalanceFormatting.swift
//  Fitness Coach
//
//  Forma — Display formatting for the Macro Balance card.
//

import Foundation

enum TodayMacroBalanceDisplayState: Equatable {
    case belowTarget
    case nearTarget
    case overTarget
    case missingTarget
}

struct TodayMacroBalanceRowDisplayModel: Equatable {
    var name: String
    var ratioText: String
    var remainingText: String
    var barProgress: Double
    var displayState: TodayMacroBalanceDisplayState
    var isProteinPriority: Bool
    var accessibilityLabel: String
    var accessibilityValue: String
}

struct TodayMacroBalanceCardDisplayModel: Equatable {
    var protein: TodayMacroBalanceRowDisplayModel
    var carbs: TodayMacroBalanceRowDisplayModel
    var fat: TodayMacroBalanceRowDisplayModel
    var accessibilitySummary: String
}

enum TodayMacroBalanceFormatting {

    /// Remaining grams at or below this share of the macro target count as “near target”.
    static let nearTargetRemainingRatio = TodayMissionHeroFormatter.nearTargetRemainingRatio

    /// Absolute gram threshold for near-target on small macro targets.
    static let nearTargetRemainingGrams = 15.0

    static func displayModel(for macros: MacroSummary) -> TodayMacroBalanceCardDisplayModel {
        let protein = rowDisplayModel(
            name: FormaProductCopy.Today.MacroBalance.protein,
            progress: macros.protein,
            isProteinPriority: true
        )
        let carbs = rowDisplayModel(
            name: FormaProductCopy.Today.MacroBalance.carbs,
            progress: macros.carbs,
            isProteinPriority: false
        )
        let fat = rowDisplayModel(
            name: FormaProductCopy.Today.MacroBalance.fat,
            progress: macros.fat,
            isProteinPriority: false
        )

        return TodayMacroBalanceCardDisplayModel(
            protein: protein,
            carbs: carbs,
            fat: fat,
            accessibilitySummary: accessibilitySummary(protein: protein, carbs: carbs, fat: fat)
        )
    }

    static func rowDisplayModel(
        name: String,
        progress: MacroProgress,
        isProteinPriority: Bool
    ) -> TodayMacroBalanceRowDisplayModel {
        let state = displayState(for: progress)
        let ratioText = ratioText(consumed: progress.consumed, target: progress.target)
        let remainingText = remainingText(for: progress, state: state)
        let barProgress = barProgress(for: progress)

        return TodayMacroBalanceRowDisplayModel(
            name: name,
            ratioText: ratioText,
            remainingText: remainingText,
            barProgress: barProgress,
            displayState: state,
            isProteinPriority: isProteinPriority,
            accessibilityLabel: name,
            accessibilityValue: accessibilityValue(
                ratioText: ratioText,
                remainingText: remainingText,
                barProgress: barProgress,
                state: state
            )
        )
    }

    static func displayState(for progress: MacroProgress) -> TodayMacroBalanceDisplayState {
        guard progress.target > 0 else { return .missingTarget }
        if progress.consumed > progress.target { return .overTarget }

        let remaining = effectiveRemaining(progress)
        if remaining <= 0 { return .nearTarget }

        if progress.consumed > 0 {
            let remainingRatio = remaining / progress.target
            if remainingRatio <= nearTargetRemainingRatio || remaining <= nearTargetRemainingGrams {
                return .nearTarget
            }
        }

        return .belowTarget
    }

    static func ratioText(consumed: Double, target: Double) -> String {
        guard target > 0 else {
            return FormaProductCopy.Today.MacroBalance.loggedAmount(consumed)
        }
        return FormaProductCopy.Today.MacroBalance.ratio(consumed: consumed, target: target)
    }

    static func remainingText(
        for progress: MacroProgress,
        state: TodayMacroBalanceDisplayState
    ) -> String {
        switch state {
        case .missingTarget:
            return FormaProductCopy.Today.MacroBalance.noTarget
        case .overTarget:
            return FormaProductCopy.Today.MacroBalance.over(grams: abs(effectiveRemaining(progress)))
        case .nearTarget:
            let remaining = effectiveRemaining(progress)
            if remaining <= 0 {
                return FormaProductCopy.Today.MacroBalance.atTarget
            }
            return FormaProductCopy.Today.MacroBalance.remaining(grams: remaining)
        case .belowTarget:
            return FormaProductCopy.Today.MacroBalance.remaining(grams: effectiveRemaining(progress))
        }
    }

    static func barProgress(for progress: MacroProgress) -> Double {
        guard progress.target > 0 else { return 0 }
        return min(max(progress.consumed / progress.target, 0), 1)
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
        let percent = Int((barProgress * 100).rounded())
        switch state {
        case .missingTarget:
            return "\(ratioText). \(remainingText)"
        case .overTarget:
            return "\(ratioText). \(remainingText). Target reached."
        default:
            return "\(ratioText). \(remainingText). \(percent) percent of target."
        }
    }

    private static func accessibilitySummary(
        protein: TodayMacroBalanceRowDisplayModel,
        carbs: TodayMacroBalanceRowDisplayModel,
        fat: TodayMacroBalanceRowDisplayModel
    ) -> String {
        [
            FormaProductCopy.Today.MacroBalance.sectionTitle,
            rowAccessibilitySummary(protein),
            rowAccessibilitySummary(carbs),
            rowAccessibilitySummary(fat)
        ].joined(separator: ". ")
    }

    private static func rowAccessibilitySummary(_ row: TodayMacroBalanceRowDisplayModel) -> String {
        "\(row.name): \(row.accessibilityValue)"
    }
}
