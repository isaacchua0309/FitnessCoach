//
//  PlanHeaderStateBuilder.swift
//  Fitness Coach
//
//  Forma — Plan screen header presentation state.
//

import Foundation

enum PlanHeaderStateBuilder {

    static func build() -> PlanHeaderState {
        let title = FormaProductCopy.PlanHeader.title
        let subtitle = FormaProductCopy.PlanHeader.subtitle

        return PlanHeaderState(
            title: title,
            subtitle: subtitle,
            accessibilitySummary: "\(title). \(subtitle)"
        )
    }
}
