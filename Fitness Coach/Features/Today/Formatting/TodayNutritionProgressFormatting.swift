//
//  TodayNutritionProgressFormatting.swift
//  Fitness Coach
//
//  Forma — Unified display formatting for Today nutrition progress.
//

import Foundation

enum TodayNutritionDisplayState: Equatable {
    case belowTarget
    case nearTarget
    case overTarget
    case missingTarget
}

enum TodayNutritionRowEmphasis: Equatable {
    case primary
    case secondary
    case standard
}

struct TodayNutritionProgressRowDisplayModel: Equatable {
    var name: String
    var ratioText: String
    var remainingText: String
    var barProgress: Double
    var displayState: TodayNutritionDisplayState
    var emphasis: TodayNutritionRowEmphasis
    var accessibilityLabel: String
    var accessibilityValue: String
}

struct TodayNutritionProgressCardDisplayModel: Equatable {
    var rows: [TodayNutritionProgressRowDisplayModel]
    var accessibilitySummary: String
}

enum TodayNutritionProgressFormatting {

    static let nearTargetRemainingRatio = TodayMissionHeroFormatter.nearTargetRemainingRatio
    static let nearTargetRemainingGrams = 15.0

    static func showsCaloriesRow(calorieSummary: CalorieSummary) -> Bool {
        calorieSummary.target <= 0
    }

    static func showsWaterRow(
        water: WaterSummary,
        includesDedicatedWaterCard: Bool = true
    ) -> Bool {
        guard includesDedicatedWaterCard else { return true }
        return water.targetMl <= 0
    }

    static func displayModel(
        macros: MacroSummary,
        water: WaterSummary,
        calorieSummary: CalorieSummary,
        includesDedicatedWaterCard: Bool = true
    ) -> TodayNutritionProgressCardDisplayModel {
        let shouldShowWaterRow = showsWaterRow(
            water: water,
            includesDedicatedWaterCard: includesDedicatedWaterCard
        )
        var rows: [TodayNutritionProgressRowDisplayModel] = [
            macroRow(
                name: FormaProductCopy.Today.MacroBalance.protein,
                progress: macros.protein,
                emphasis: .primary
            )
        ]

        if showsCaloriesRow(calorieSummary: calorieSummary) {
            rows.append(caloriesRow(from: calorieSummary))
        }

        rows.append(
            contentsOf: [
                macroRow(
                    name: FormaProductCopy.Today.MacroBalance.carbs,
                    progress: macros.carbs,
                    emphasis: .secondary
                ),
                macroRow(
                    name: FormaProductCopy.Today.MacroBalance.fat,
                    progress: macros.fat,
                    emphasis: .secondary
                )
            ]
        )

        if shouldShowWaterRow {
            rows.append(waterRow(from: water))
        }

        return TodayNutritionProgressCardDisplayModel(
            rows: rows,
            accessibilitySummary: accessibilitySummary(rows: rows)
        )
    }

    static func macroRow(
        name: String,
        progress: MacroProgress,
        emphasis: TodayNutritionRowEmphasis
    ) -> TodayNutritionProgressRowDisplayModel {
        let state = displayState(
            consumed: progress.consumed,
            target: progress.target,
            remaining: progress.remaining
        )
        let ratioText = macroRatioText(consumed: progress.consumed, target: progress.target)
        let remainingText = macroRemainingText(
            consumed: progress.consumed,
            target: progress.target,
            state: state
        )
        let barProgress = barProgress(consumed: progress.consumed, target: progress.target)

        return TodayNutritionProgressRowDisplayModel(
            name: name,
            ratioText: ratioText,
            remainingText: remainingText,
            barProgress: barProgress,
            displayState: state,
            emphasis: emphasis,
            accessibilityLabel: name,
            accessibilityValue: accessibilityValue(
                ratioText: ratioText,
                remainingText: remainingText,
                barProgress: barProgress,
                state: state
            )
        )
    }

    static func caloriesRow(from summary: CalorieSummary) -> TodayNutritionProgressRowDisplayModel {
        let consumed = Double(summary.consumed)
        let target = Double(summary.target)
        let state = displayState(
            consumed: consumed,
            target: target,
            remaining: Double(summary.remaining)
        )
        let ratioText = caloriesRatioText(consumed: summary.consumed, target: summary.target)
        let remainingText = caloriesRemainingText(summary: summary, state: state)
        let barProgress = barProgress(consumed: consumed, target: target)

        return TodayNutritionProgressRowDisplayModel(
            name: FormaProductCopy.Today.MacroBalance.calories,
            ratioText: ratioText,
            remainingText: remainingText,
            barProgress: barProgress,
            displayState: state,
            emphasis: .secondary,
            accessibilityLabel: FormaProductCopy.Today.MacroBalance.calories,
            accessibilityValue: accessibilityValue(
                ratioText: ratioText,
                remainingText: remainingText,
                barProgress: barProgress,
                state: state
            )
        )
    }

    static func waterRow(from summary: WaterSummary) -> TodayNutritionProgressRowDisplayModel {
        let consumed = Double(summary.consumedMl)
        let target = Double(summary.targetMl)
        let state = displayState(
            consumed: consumed,
            target: target,
            remaining: Double(summary.remainingMl)
        )
        let ratioText = waterRatioText(consumedMl: summary.consumedMl, targetMl: summary.targetMl)
        let remainingText = waterRemainingText(summary: summary, state: state)
        let barProgress = barProgress(consumed: consumed, target: target)

        return TodayNutritionProgressRowDisplayModel(
            name: FormaProductCopy.Today.MacroBalance.water,
            ratioText: ratioText,
            remainingText: remainingText,
            barProgress: barProgress,
            displayState: state,
            emphasis: .standard,
            accessibilityLabel: FormaProductCopy.Today.MacroBalance.water,
            accessibilityValue: accessibilityValue(
                ratioText: ratioText,
                remainingText: remainingText,
                barProgress: barProgress,
                state: state
            )
        )
    }

    static func isProteinBehind(_ progress: MacroProgress) -> Bool {
        guard progress.target > 0 else { return false }
        return displayState(
            consumed: progress.consumed,
            target: progress.target,
            remaining: progress.remaining
        ) == .belowTarget
    }

    static func isProteinTargetHit(_ progress: MacroProgress) -> Bool {
        guard progress.target > 0 else { return false }
        switch displayState(
            consumed: progress.consumed,
            target: progress.target,
            remaining: progress.remaining
        ) {
        case .nearTarget, .overTarget:
            return true
        case .belowTarget, .missingTarget:
            return false
        }
    }

    static func isWaterBehind(_ summary: WaterSummary) -> Bool {
        guard summary.targetMl > 0 else { return false }
        return displayState(
            consumed: Double(summary.consumedMl),
            target: Double(summary.targetMl),
            remaining: Double(summary.remainingMl)
        ) == .belowTarget
    }

    static func isWaterTargetHit(_ summary: WaterSummary) -> Bool {
        guard summary.targetMl > 0 else { return false }
        switch displayState(
            consumed: Double(summary.consumedMl),
            target: Double(summary.targetMl),
            remaining: Double(summary.remainingMl)
        ) {
        case .nearTarget, .overTarget:
            return true
        case .belowTarget, .missingTarget:
            return false
        }
    }

    // MARK: - Display state

    static func displayState(
        consumed: Double,
        target: Double,
        remaining: Double
    ) -> TodayNutritionDisplayState {
        guard target > 0 else { return .missingTarget }
        if consumed > target { return .overTarget }

        let effectiveRemaining = target - consumed
        if effectiveRemaining <= 0 { return .nearTarget }

        if consumed > 0 {
            let remainingRatio = effectiveRemaining / target
            if remainingRatio <= nearTargetRemainingRatio || effectiveRemaining <= nearTargetRemainingGrams {
                return .nearTarget
            }
        }

        return .belowTarget
    }

    // MARK: - Ratio + remaining copy

    static func macroRatioText(consumed: Double, target: Double) -> String {
        guard target > 0 else {
            return FormaProductCopy.Today.MacroBalance.loggedAmount(consumed)
        }
        return FormaProductCopy.Today.MacroBalance.ratio(consumed: consumed, target: target)
    }

    static func macroRemainingText(
        consumed: Double,
        target: Double,
        state: TodayNutritionDisplayState
    ) -> String {
        switch state {
        case .missingTarget:
            return FormaProductCopy.Today.MacroBalance.noTarget
        case .overTarget:
            return FormaProductCopy.Today.MacroBalance.over(grams: max(consumed - target, 0))
        case .nearTarget:
            let remaining = max(target - consumed, 0)
            if remaining <= 0 {
                return FormaProductCopy.Today.MacroBalance.atTarget
            }
            return FormaProductCopy.Today.MacroBalance.remaining(grams: remaining)
        case .belowTarget:
            return FormaProductCopy.Today.MacroBalance.remaining(grams: max(target - consumed, 0))
        }
    }

    static func caloriesRatioText(consumed: Int, target: Int) -> String {
        guard target > 0 else {
            return FormaProductCopy.Today.MacroBalance.loggedCalories(consumed)
        }
        return FormaProductCopy.Today.MacroBalance.caloriesRatio(consumed: consumed, target: target)
    }

    static func caloriesRemainingText(
        summary: CalorieSummary,
        state: TodayNutritionDisplayState
    ) -> String {
        switch state {
        case .missingTarget:
            return FormaProductCopy.Today.MacroBalance.noTarget
        case .overTarget:
            return FormaProductCopy.Today.MacroBalance.caloriesOver(
                max(summary.consumed - summary.target, 0)
            )
        case .nearTarget:
            if summary.remaining <= 0 {
                return FormaProductCopy.Today.MacroBalance.atTarget
            }
            return FormaProductCopy.Today.MacroBalance.caloriesRemaining(max(summary.remaining, 0))
        case .belowTarget:
            return FormaProductCopy.Today.MacroBalance.caloriesRemaining(max(summary.remaining, 0))
        }
    }

    static func waterRatioText(consumedMl: Int, targetMl: Int) -> String {
        guard targetMl > 0 else {
            return FormaProductCopy.Today.MacroBalance.loggedWater(consumedMl)
        }
        return FormaProductCopy.Today.MacroBalance.waterRatio(consumedMl: consumedMl, targetMl: targetMl)
    }

    static func waterRemainingText(
        summary: WaterSummary,
        state: TodayNutritionDisplayState
    ) -> String {
        switch state {
        case .missingTarget:
            return FormaProductCopy.Today.MacroBalance.noTarget
        case .overTarget:
            return FormaProductCopy.Today.MacroBalance.waterOver(
                max(summary.consumedMl - summary.targetMl, 0)
            )
        case .nearTarget:
            if summary.remainingMl <= 0 {
                return FormaProductCopy.Today.MacroBalance.atTarget
            }
            return FormaProductCopy.Today.MacroBalance.waterRemaining(summary.remainingMl)
        case .belowTarget:
            return FormaProductCopy.Today.MacroBalance.waterRemaining(max(summary.remainingMl, 0))
        }
    }

    static func barProgress(consumed: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(consumed / target, 0), 1)
    }

    static func accessibilityValue(
        ratioText: String,
        remainingText: String,
        barProgress: Double,
        state: TodayNutritionDisplayState
    ) -> String {
        let percent = Int((barProgress * 100).rounded())
        switch state {
        case .missingTarget:
            return "\(ratioText). \(remainingText)"
        case .overTarget:
            return "\(ratioText). \(remainingText)."
        default:
            return "\(ratioText). \(remainingText). \(percent) percent of target."
        }
    }

    private static func accessibilitySummary(rows: [TodayNutritionProgressRowDisplayModel]) -> String {
        ([FormaProductCopy.Today.MacroBalance.sectionTitle] + rows.map {
            "\($0.name): \($0.accessibilityValue)"
        }).joined(separator: ". ")
    }
}
