//
//  ThemeAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed theme settings analytics events and safe property bag.
//

import Foundation

enum ThemeAnalyticsEvent: String, Sendable {
    case settingsViewed = "theme_settings_viewed"
    case appearanceModeChanged = "appearance_mode_changed"
    case paletteChanged = "theme_palette_changed"
}

enum ThemeAnalyticsSource: String, Sendable {
    case settings
}

struct ThemeAnalyticsProperties: Sendable {
    var previousAppearance: String?
    var newAppearance: String?
    var previousPalette: String?
    var newPalette: String?
    var source: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let previousAppearance { parameters["previousAppearance"] = previousAppearance }
        if let newAppearance { parameters["newAppearance"] = newAppearance }
        if let previousPalette { parameters["previousPalette"] = previousPalette }
        if let newPalette { parameters["newPalette"] = newPalette }
        if let source { parameters["source"] = source }
        return parameters
    }
}

protocol ThemeAnalyticsLogging: Sendable {
    func log(_ event: ThemeAnalyticsEvent, properties: ThemeAnalyticsProperties)
}

extension ThemeAnalyticsProperties {

    static func settingsViewed(source: ThemeAnalyticsSource = .settings) -> ThemeAnalyticsProperties {
        ThemeAnalyticsProperties(source: source.rawValue)
    }

    static func appearanceChange(
        previous: AppAppearanceMode,
        new: AppAppearanceMode,
        source: ThemeAnalyticsSource = .settings
    ) -> ThemeAnalyticsProperties {
        ThemeAnalyticsProperties(
            previousAppearance: previous.rawValue,
            newAppearance: new.rawValue,
            source: source.rawValue
        )
    }

    static func paletteChange(
        previous: AppThemePalette,
        new: AppThemePalette,
        source: ThemeAnalyticsSource = .settings
    ) -> ThemeAnalyticsProperties {
        ThemeAnalyticsProperties(
            previousPalette: previous.persistenceRawValue,
            newPalette: new.persistenceRawValue,
            source: source.rawValue
        )
    }
}
