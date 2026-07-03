//
//  SettingsAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — Settings analytics events, properties, and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class SettingsAnalyticsTests: XCTestCase {

    private var analytics: CapturingSettingsAnalyticsLogger!
    private var coordinator: SettingsAnalyticsCoordinator!

    override func setUp() {
        super.setUp()
        analytics = CapturingSettingsAnalyticsLogger()
        coordinator = SettingsAnalyticsCoordinator(analyticsLogger: analytics)
        coordinator.updateContext(
            unitSystem: .metric,
            themePalette: .oceanBlue,
            integrationState: .connected
        )
    }

    // MARK: - Event names

    func testSettingsAnalyticsEventNames() {
        XCTAssertEqual(SettingsAnalyticsEvent.settingsViewed.rawValue, "settings_viewed")
        XCTAssertEqual(SettingsAnalyticsEvent.settingsRowTapped.rawValue, "settings_row_tapped")
        XCTAssertEqual(SettingsAnalyticsEvent.accountViewed.rawValue, "account_viewed")
        XCTAssertEqual(SettingsAnalyticsEvent.appleHealthSettingsViewed.rawValue, "apple_health_settings_viewed")
        XCTAssertEqual(SettingsAnalyticsEvent.themeSettingsViewed.rawValue, "theme_settings_viewed")
        XCTAssertEqual(SettingsAnalyticsEvent.unitsSettingsViewed.rawValue, "units_settings_viewed")
        XCTAssertEqual(SettingsAnalyticsEvent.bodyStatsViewed.rawValue, "body_stats_viewed")
        XCTAssertEqual(SettingsAnalyticsEvent.privacyPolicyTapped.rawValue, "privacy_policy_tapped")
        XCTAssertEqual(SettingsAnalyticsEvent.termsTapped.rawValue, "terms_tapped")
        XCTAssertEqual(SettingsAnalyticsEvent.supportTapped.rawValue, "support_tapped")
        XCTAssertEqual(SettingsAnalyticsEvent.logoutTapped.rawValue, "logout_tapped")
        XCTAssertEqual(SettingsAnalyticsEvent.logoutConfirmed.rawValue, "logout_confirmed")
    }

    // MARK: - Coordinator

    func testSettingsViewedIncludesContextProperties() {
        coordinator.logSettingsViewed()

        let properties = analytics.lastProperties(for: .settingsViewed)
        XCTAssertEqual(properties?["unit_system"], "metric")
        XCTAssertEqual(properties?["theme_name"], "oceanBlue")
        XCTAssertEqual(properties?["apple_health_status"], "connected")
        #if DEBUG
        XCTAssertEqual(properties?["build_type"], "debug")
        #endif
    }

    func testRowTappedIncludesRowAndSectionType() {
        coordinator.logRowTapped(rowID: .theme, sectionType: .preferences)

        let properties = analytics.lastProperties(for: .settingsRowTapped)
        XCTAssertEqual(properties?["row_type"], "theme")
        XCTAssertEqual(properties?["section_type"], "preferences")
    }

    func testPrivacyPolicyTappedFromPrivacySection() {
        coordinator.logPrivacyPolicyTapped(sectionType: .privacyData)

        let properties = analytics.lastProperties(for: .privacyPolicyTapped)
        XCTAssertEqual(properties?["row_type"], "privacy_policy")
        XCTAssertEqual(properties?["section_type"], "privacy_data")
    }

    func testTermsTappedFromAboutSection() {
        coordinator.logTermsTapped(sectionType: .about)

        let properties = analytics.lastProperties(for: .termsTapped)
        XCTAssertEqual(properties?["row_type"], "terms_of_service")
        XCTAssertEqual(properties?["section_type"], "about")
    }

    func testSupportTappedLogsSupportAndRowEvents() {
        coordinator.logSupportTapped(topic: .feedback)

        XCTAssertTrue(analytics.contains(.supportTapped))
        XCTAssertTrue(analytics.contains(.settingsRowTapped))
        XCTAssertEqual(analytics.lastProperties(for: .supportTapped)?["row_type"], "send_feedback")
    }

    func testLogoutFlowLogsTappedAndConfirmed() {
        coordinator.logLogoutTapped()
        coordinator.logLogoutConfirmed()

        XCTAssertEqual(analytics.eventCount(for: .logoutTapped), 1)
        XCTAssertEqual(analytics.eventCount(for: .logoutConfirmed), 1)
        XCTAssertEqual(analytics.lastProperties(for: .logoutTapped)?["row_type"], "logout")
    }

    func testScreenViewEvents() {
        coordinator.logAccountViewed()
        coordinator.logAppleHealthSettingsViewed()
        coordinator.logThemeSettingsViewed()
        coordinator.logUnitsSettingsViewed()
        coordinator.logBodyStatsViewed()

        XCTAssertTrue(analytics.contains(.accountViewed))
        XCTAssertTrue(analytics.contains(.appleHealthSettingsViewed))
        XCTAssertTrue(analytics.contains(.themeSettingsViewed))
        XCTAssertTrue(analytics.contains(.unitsSettingsViewed))
        XCTAssertTrue(analytics.contains(.bodyStatsViewed))
    }

    // MARK: - Privacy

    func testPropertiesExcludeSensitiveFields() {
        let bannedTerms = [
            "email", "name", "age", "sex", "weight", "height", "calorie", "health_value"
        ]

        coordinator.logSettingsViewed()
        coordinator.logRowTapped(rowID: .bodyAndStats, sectionType: .preferences)
        coordinator.logBodyStatsViewed()
        coordinator.logPrivacyPolicyTapped(sectionType: .privacyData)
        coordinator.logLogoutTapped()

        for entry in analytics.events {
            let parameters = entry.properties.asParameters()
            XCTAssertTrue(SettingsAnalyticsContextBuilder.isPrivacySafe(parameters))
            for key in parameters.keys {
                let lowered = key.lowercased()
                for banned in bannedTerms {
                    XCTAssertFalse(lowered.contains(banned), "Unexpected key \"\(key)\"")
                }
            }
        }
    }

    func testAppleHealthStatusUsesBucketedValues() {
        XCTAssertEqual(SettingsAnalyticsContextBuilder.appleHealthStatus(.connected), "connected")
        XCTAssertEqual(SettingsAnalyticsContextBuilder.appleHealthStatus(.denied), "denied")
        XCTAssertEqual(SettingsAnalyticsContextBuilder.appleHealthStatus(.notConnected), "not_connected")
    }
}
