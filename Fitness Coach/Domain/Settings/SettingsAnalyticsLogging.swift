//
//  SettingsAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Settings analytics events and safe property bag.
//

import Foundation

enum SettingsAnalyticsEvent: String, Sendable {
    case settingsViewed = "settings_viewed"
    case settingsRowTapped = "settings_row_tapped"
    case accountViewed = "account_viewed"
    case appleHealthSettingsViewed = "apple_health_settings_viewed"
    case themeSettingsViewed = "theme_settings_viewed"
    case unitsSettingsViewed = "units_settings_viewed"
    case bodyStatsViewed = "body_stats_viewed"
    case privacyPolicyTapped = "privacy_policy_tapped"
    case termsTapped = "terms_tapped"
    case supportTapped = "support_tapped"
    case logoutTapped = "logout_tapped"
    case logoutConfirmed = "logout_confirmed"
}

enum SettingsAnalyticsSectionType: String, Sendable {
    case account
    case preferences
    case integrations
    case privacyData = "privacy_data"
    case support
    case about
    case developer
}

struct SettingsAnalyticsProperties: Sendable {
    var rowType: String?
    var sectionType: String?
    var appleHealthStatus: String?
    var unitSystem: String?
    var themeName: String?
    var buildType: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let rowType { parameters["row_type"] = rowType }
        if let sectionType { parameters["section_type"] = sectionType }
        if let appleHealthStatus { parameters["apple_health_status"] = appleHealthStatus }
        if let unitSystem { parameters["unit_system"] = unitSystem }
        if let themeName { parameters["theme_name"] = themeName }
        if let buildType { parameters["build_type"] = buildType }
        return parameters
    }
}

protocol SettingsAnalyticsLogging: Sendable {
    func log(_ event: SettingsAnalyticsEvent, properties: SettingsAnalyticsProperties)
}
