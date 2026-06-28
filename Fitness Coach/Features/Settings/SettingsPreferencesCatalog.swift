//
//  SettingsPreferencesCatalog.swift
//  Fitness Coach
//
//  Forma — Testable Preferences section metadata for Settings.
//

import Foundation

enum SettingsPreferencesCatalog {
    static let sectionTitle = "Preferences"
    static let themeRowTitle = FormaProductCopy.Settings.Theme.navigationRowTitle

    static let rowTitles: [String] = [
        "Units",
        FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle,
        themeRowTitle,
        "AI preferences"
    ]
}
