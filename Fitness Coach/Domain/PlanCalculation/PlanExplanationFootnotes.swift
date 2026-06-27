//
//  PlanExplanationFootnotes.swift
//  Fitness Coach
//
//  Maps engine PlanCalculationExplanation lines to details-sheet row footnotes.
//

import Foundation

enum PlanExplanationFootnotes {

    /// Footnote text keyed by `PlanCalculationDetailsRow` id.
    static func footnotes(from result: PlanCalculationResult) -> [String: String] {
        let explanation = result.explanation
        var map: [String: String] = [
            "bmr": explanation.bmrLine,
            "maintenance": explanation.tdeeLine,
            "calories": explanation.calorieTargetLine,
            "protein": explanation.proteinLine,
            "water": explanation.waterLine
        ]

        if let lossRateLine = explanation.lossRateLine {
            map["pace"] = lossRateLine
        }
        if let dailyDeficitLine = explanation.dailyDeficitLine {
            map["deficit"] = dailyDeficitLine
        }

        return map
    }

    static func footnote(
        for rowID: String,
        result: PlanCalculationResult,
        fallback: String
    ) -> String {
        footnotes(from: result)[rowID] ?? fallback
    }
}
