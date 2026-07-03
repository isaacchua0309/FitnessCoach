//
//  SettingsAnalyticsCoordinator.swift
//  Fitness Coach
//
//  Forma — Settings screen and interaction analytics (read-only, bucketed).
//

import Foundation

@MainActor
final class SettingsAnalyticsCoordinator {

    private let analyticsLogger: any SettingsAnalyticsLogging
    private var unitSystem: UnitSystem?
    private var themeName: String?
    private var appleHealthStatus: String?

    init(analyticsLogger: any SettingsAnalyticsLogging = NoOpSettingsAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    func updateContext(
        unitSystem: UnitSystem,
        themePalette: AppThemePalette,
        integrationState: TrainingIntegrationState
    ) {
        self.unitSystem = unitSystem
        themeName = SettingsAnalyticsContextBuilder.themeName(themePalette)
        appleHealthStatus = SettingsAnalyticsContextBuilder.appleHealthStatus(integrationState)
    }

    func logSettingsViewed() {
        log(.settingsViewed)
    }

    func logRowTapped(rowID: SettingsRowID, sectionType: SettingsAnalyticsSectionType) {
        log(.settingsRowTapped) { properties in
            properties.rowType = SettingsAnalyticsContextBuilder.rowType(for: rowID)
            properties.sectionType = sectionType.rawValue
        }
    }

    func logAccountViewed() {
        log(.accountViewed)
    }

    func logAppleHealthSettingsViewed() {
        log(.appleHealthSettingsViewed)
    }

    func logThemeSettingsViewed() {
        log(.themeSettingsViewed)
    }

    func logUnitsSettingsViewed() {
        log(.unitsSettingsViewed)
    }

    func logBodyStatsViewed() {
        log(.bodyStatsViewed)
    }

    func logPrivacyPolicyTapped(sectionType: SettingsAnalyticsSectionType) {
        log(.privacyPolicyTapped) { properties in
            properties.rowType = SettingsAnalyticsContextBuilder.rowType(for: .privacyPolicy)
            properties.sectionType = sectionType.rawValue
        }
    }

    func logTermsTapped(sectionType: SettingsAnalyticsSectionType) {
        log(.termsTapped) { properties in
            properties.rowType = SettingsAnalyticsContextBuilder.rowType(for: .termsOfService)
            properties.sectionType = sectionType.rawValue
        }
    }

    func logSupportTapped(topic: SettingsSupportMailTopic, sectionType: SettingsAnalyticsSectionType = .support) {
        log(.supportTapped) { properties in
            properties.rowType = SettingsAnalyticsContextBuilder.rowType(for: topic)
            properties.sectionType = sectionType.rawValue
        }
        let rowID: SettingsRowID = switch topic {
        case .feedback: .sendFeedback
        case .contactSupport: .contactSupport
        case .reportProblem: .reportProblem
        }
        logRowTapped(rowID: rowID, sectionType: sectionType)
    }

    func logLogoutTapped() {
        log(.logoutTapped) { properties in
            properties.rowType = "logout"
            properties.sectionType = SettingsAnalyticsSectionType.account.rawValue
        }
    }

    func logLogoutConfirmed() {
        log(.logoutConfirmed) { properties in
            properties.rowType = "logout"
            properties.sectionType = SettingsAnalyticsSectionType.account.rawValue
        }
    }

    private func log(
        _ event: SettingsAnalyticsEvent,
        configure: (inout SettingsAnalyticsProperties) -> Void = { _ in }
    ) {
        var properties = SettingsAnalyticsContextBuilder.baseProperties(
            unitSystem: unitSystem,
            themeName: themeName,
            appleHealthStatus: appleHealthStatus
        )
        configure(&properties)
        analyticsLogger.log(event, properties: properties)
    }
}
