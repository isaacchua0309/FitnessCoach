//
//  SettingsProductionVisibility.swift
//  Fitness Coach
//
//  Forma — Documents which Settings rows are hidden in production builds.
//

import Foundation

enum SettingsProductionVisibility {

    static let hiddenRowIDs: Set<SettingsRowID> = [
        .exportData,
        .authDiagnostics,
        .pipelineTraces,
        .coachContextInspector
    ]

    static let prohibitedTitleTerms = [
        "coming soon",
        "ai preferences",
        "daily reminders",
        "coach check-ins",
        "coach check-in"
    ]

    static func isHiddenInProduction(_ rowID: SettingsRowID) -> Bool {
        hiddenRowIDs.contains(rowID)
    }

    static func containsProhibitedPlaceholderCopy(_ titles: [String]) -> Bool {
        titles.contains { title in
            let lowered = title.lowercased()
            return prohibitedTitleTerms.contains(where: { lowered.contains($0) })
        }
    }
}
