//
//  BodyDetailsSettingsActionHandler.swift
//  Fitness Coach
//
//  Forma — Routes Body & stats updates through Adjust Plan.
//

import Foundation

enum BodyDetailsSettingsActionHandler {

    static func openUpdateInPlan(
        dismissSettings: () -> Void,
        showAdjustPlan: () -> Void
    ) {
        dismissSettings()
        showAdjustPlan()
    }
}
