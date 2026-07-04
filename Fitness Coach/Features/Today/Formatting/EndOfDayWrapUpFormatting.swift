//
//  EndOfDayWrapUpFormatting.swift
//  Fitness Coach
//
//  Display formatting for Today end-of-day wrap-up rows.
//

import Foundation

enum EndOfDayWrapUpFormatting {

    static func rows(for input: EndOfDayWrapUpInput) -> [TodayEndOfDayRowState] {
        [
            caloriesRow(from: input.calorieSummary, hasMeals: !input.foodEntries.isEmpty),
            proteinRow(from: input.proteinProgress, hasMeals: !input.foodEntries.isEmpty),
            waterRow(from: input.waterSummary),
            workoutRow(
                hasWorkout: EndOfDayWrapUpEngine.hasWorkoutToday(input)
            )
        ]
    }

    static func caloriesRow(
        from summary: CalorieSummary,
        hasMeals: Bool
    ) -> TodayEndOfDayRowState {
        guard hasMeals, summary.consumed > 0 else {
            return notLoggedRow(label: FormaProductCopy.Today.EndOfDay.rowCalories)
        }

        let state = TodayNutritionProgressFormatting.displayState(
            consumed: Double(summary.consumed),
            target: Double(summary.target),
            remaining: Double(summary.remaining)
        )

        return TodayEndOfDayRowState(
            label: FormaProductCopy.Today.EndOfDay.rowCalories,
            valueText: TodayNutritionProgressFormatting.caloriesRatioText(
                consumed: summary.consumed,
                target: summary.target
            ),
            status: rowStatus(for: state, isOver: summary.isOverTarget)
        )
    }

    static func proteinRow(
        from progress: MacroProgress,
        hasMeals: Bool
    ) -> TodayEndOfDayRowState {
        guard hasMeals, progress.consumed > 0 else {
            return notLoggedRow(label: FormaProductCopy.Today.EndOfDay.rowProtein)
        }

        let state = TodayNutritionProgressFormatting.displayState(
            consumed: progress.consumed,
            target: progress.target,
            remaining: progress.remaining
        )

        return TodayEndOfDayRowState(
            label: FormaProductCopy.Today.EndOfDay.rowProtein,
            valueText: TodayNutritionProgressFormatting.macroRatioText(
                consumed: progress.consumed,
                target: progress.target
            ),
            status: rowStatus(for: state, isOver: progress.consumed > progress.target)
        )
    }

    static func waterRow(from summary: WaterSummary) -> TodayEndOfDayRowState {
        guard summary.consumedMl > 0 else {
            return notLoggedRow(label: FormaProductCopy.Today.EndOfDay.rowWater)
        }

        let state = TodayNutritionProgressFormatting.displayState(
            consumed: Double(summary.consumedMl),
            target: Double(summary.targetMl),
            remaining: Double(summary.remainingMl)
        )

        return TodayEndOfDayRowState(
            label: FormaProductCopy.Today.EndOfDay.rowWater,
            valueText: TodayNutritionProgressFormatting.waterRatioText(
                consumedMl: summary.consumedMl,
                targetMl: summary.targetMl
            ),
            status: rowStatus(for: state, isOver: summary.consumedMl > summary.targetMl)
        )
    }

    static func workoutRow(hasWorkout: Bool) -> TodayEndOfDayRowState {
        TodayEndOfDayRowState(
            label: FormaProductCopy.Today.EndOfDay.rowWorkout,
            valueText: hasWorkout
                ? FormaProductCopy.Today.EndOfDay.workoutCompleted
                : FormaProductCopy.Today.EndOfDay.workoutNotLogged,
            status: hasWorkout ? .complete : .notLogged
        )
    }

    private static func notLoggedRow(label: String) -> TodayEndOfDayRowState {
        TodayEndOfDayRowState(
            label: label,
            valueText: FormaProductCopy.Today.EndOfDay.rowNotLogged,
            status: .notLogged
        )
    }

    private static func rowStatus(
        for state: TodayNutritionDisplayState,
        isOver: Bool
    ) -> TodayEndOfDayRowStatus {
        if isOver {
            return .overTarget
        }

        switch state {
        case .nearTarget, .overTarget:
            return .complete
        case .belowTarget:
            return .partial
        case .missingTarget:
            return .notLogged
        }
    }
}
