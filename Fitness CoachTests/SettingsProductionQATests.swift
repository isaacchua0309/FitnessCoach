//
//  SettingsProductionQATests.swift
//  Fitness CoachTests
//
//  Forma — Production Settings QA checklist (hub visibility, navigation, privacy).
//

import XCTest
@testable import Fitness_Coach

final class SettingsProductionQATests: XCTestCase {

    // MARK: - Fixtures

    private func productionInput(
        supportConfiguration: SettingsSupportConfiguration = .production,
        hasAccountDeletionCoordinator: Bool = true
    ) -> SettingsPresentationInput {
        SettingsPresentationInput(
            integrationState: .connected,
            unitSystem: .metric,
            themePalette: .oceanBlue,
            appVersion: "2.4.1",
            featureAvailability: .production,
            legalAvailability: .production,
            supportConfiguration: supportConfiguration,
            isDebugOrInternalBuild: false,
            accountDeletionWiring: SettingsAccountDeletionWiring(
                featureAvailability: .production,
                hasCoordinator: hasAccountDeletionCoordinator
            )
        )
    }

    private func debugInput() -> SettingsPresentationInput {
        SettingsPresentationInput(
            integrationState: .connected,
            unitSystem: .metric,
            themePalette: .oceanBlue,
            appVersion: "2.4.1",
            featureAvailability: .production,
            legalAvailability: .production,
            supportConfiguration: .production,
            isDebugOrInternalBuild: true,
            accountDeletionWiring: SettingsAccountDeletionWiring(
                featureAvailability: .production,
                hasCoordinator: true
            )
        )
    }

    private func productionState(
        supportConfiguration: SettingsSupportConfiguration = .production
    ) -> SettingsPresentationState {
        SettingsPresentationBuilder.build(input: productionInput(supportConfiguration: supportConfiguration))
    }

    private func allRowTitles(in state: SettingsPresentationState) -> [String] {
        var titles: [String] = []
        titles += state.account.rows.map(\.title)
        titles += state.preferences.rows.map(\.title)
        titles += state.integrations.rows.map(\.title)
        titles += state.privacyData.rows.map(\.title)
        if let support = state.support {
            titles += support.rows.map(\.title)
        }
        titles += state.about.rows.map(\.title)
        if let developer = state.developer {
            titles += developer.rows.map(\.title)
        }
        return titles
    }

    // MARK: - 1. Settings opens

    func testQA01_SettingsHubBuildsAllProductionSections() {
        let state = productionState()

        XCTAssertFalse(state.account.rows.isEmpty)
        XCTAssertFalse(state.preferences.rows.isEmpty)
        XCTAssertFalse(state.integrations.rows.isEmpty)
        XCTAssertFalse(state.privacyData.rows.isEmpty)
        XCTAssertNotNil(state.support)
        XCTAssertFalse(state.about.rows.isEmpty)
        XCTAssertEqual(FormaProductCopy.Settings.Hub.screenTitle, "Settings")
    }

    // MARK: - 2. Done closes Settings

    func testQA02_DoneButtonUsesAccessibleCopy() {
        XCTAssertEqual(FormaProductCopy.Common.done, "Done")
        XCTAssertEqual(FormaProductCopy.Settings.Hub.doneAccessibilityLabel, "Done")
    }

    // MARK: - 3. Account opens

    func testQA03_AccountRowIsNavigable() {
        let row = productionState().account.rows.first { $0.id == .account }

        XCTAssertNotNil(row)
        XCTAssertEqual(row?.destination, .account)
        XCTAssertTrue(row?.isNavigable ?? false)
    }

    // MARK: - 4. Logout confirmation works

    func testQA04_LogoutConfirmationCopyAndHandler() {
        let presentation = AccountSettingsPresentationBuilder.build(
            input: AccountSettingsPresentationInput(
                authState: .signedIn(uid: "user"),
                displayName: "Alex Morgan",
                email: "alex@example.com",
                signInProvider: .google
            )
        )

        XCTAssertTrue(presentation.canLogOut)
        XCTAssertFalse(presentation.logoutConfirmationTitle.isEmpty)
        XCTAssertFalse(presentation.logoutConfirmationMessage.isEmpty)

        var didSignOut = false
        AccountSettingsLogoutHandler.perform(
            performAppSignOut: { didSignOut = true },
            authManagerSignOut: { XCTFail("App sign-out should be preferred") }
        )
        XCTAssertTrue(didSignOut)
    }

    // MARK: - 5. Units opens and updates

    func testQA05_UnitsRowNavigableAndPresentationReflectsSelection() {
        let state = productionState()
        let row = state.preferences.rows.first { $0.id == .units }

        XCTAssertEqual(row?.destination, .units)
        XCTAssertTrue(row?.isNavigable ?? false)

        let presentation = UnitsSettingsPresentationBuilder.build(
            input: UnitsSettingsPresentationInput(unitSystem: .imperial)
        )
        XCTAssertEqual(presentation.selectedUnitSystem, .imperial)
    }

    // MARK: - 6. Body & Stats opens

    func testQA06_BodyAndStatsRowIsNavigable() {
        let row = productionState().preferences.rows.first { $0.id == .bodyAndStats }

        XCTAssertEqual(row?.destination, .bodyAndStats)
        XCTAssertTrue(row?.isNavigable ?? false)
    }

    // MARK: - 7. Theme opens and persists selection

    @MainActor
    func testQA07_ThemeRowNavigableAndStorePersistsPalette() {
        let row = productionState().preferences.rows.first { $0.id == .theme }

        XCTAssertEqual(row?.destination, .theme)
        XCTAssertTrue(row?.isNavigable ?? false)

        let defaults = UserDefaults(suiteName: "SettingsProductionQATests.theme.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let store = ThemeStore(userDefaults: defaults)
        store.setPalette(.blossomPink)
        XCTAssertEqual(store.palette, .blossomPink)
        XCTAssertEqual(
            SettingsRowStatusFormatter.themePalette(store.palette),
            FormaProductCopy.Settings.Theme.colorPaletteTitle(for: .blossomPink)
        )
    }

    // MARK: - 8. Apple Health opens

    func testQA08_AppleHealthRowIsNavigable() {
        let row = productionState().integrations.rows.first { $0.id == .appleHealth }

        XCTAssertEqual(row?.destination, .appleHealthIntegration)
        XCTAssertTrue(row?.isNavigable ?? false)
    }

    // MARK: - 9. Support actions work if shown

    func testQA09_SupportRowsShownWhenEmailConfigured() {
        let state = productionState()
        XCTAssertNotNil(state.support)
        XCTAssertEqual(
            state.support?.rows.map(\.id),
            [.sendFeedback, .contactSupport, .reportProblem]
        )

        for row in state.support?.rows ?? [] {
            if case .supportMail(let topic) = row.destination {
                XCTAssertNotNil(
                    SettingsSupportMailURLBuilder.url(
                        for: topic,
                        supportEmail: SettingsSupportConfiguration.production.supportEmail!,
                        diagnostics: SettingsSupportDiagnosticsBuilder.build(
                            input: SettingsSupportDiagnosticsInput(
                                appVersion: "2.4.1",
                                buildNumber: "1",
                                deviceModel: "iPhone",
                                systemVersion: "18.0"
                            )
                        )
                    )
                )
            } else {
                XCTFail("Expected support mail destination for \(row.id)")
            }
        }
    }

    func testQA09b_SupportSectionHiddenWhenEmailUnconfigured() {
        XCTAssertNil(productionState(supportConfiguration: .unconfigured).support)
    }

    // MARK: - 10. Privacy/Terms links work if shown

    func testQA10_PrivacyAndTermsResolveWhenAvailable() {
        let state = productionState()

        let privacyRow = state.privacyData.rows.first { $0.id == .privacyPolicy }
        XCTAssertNotNil(privacyRow)
        XCTAssertNotNil(state.externalURL(for: .privacyPolicy))

        let termsRow = state.about.rows.first { $0.id == .termsOfService }
        XCTAssertNotNil(termsRow)
        XCTAssertNotNil(state.externalURL(for: .terms))
    }

    // MARK: - 11. Developer section hidden in production

    func testQA11_DeveloperSectionHiddenInProduction() {
        let state = productionState()

        XCTAssertNil(state.developer)
        XCTAssertFalse(state.isDebugOrInternalBuild)
        for rowID in SettingsProductionVisibility.hiddenRowIDs {
            XCTAssertFalse(state.visibleRowIDs.contains(rowID))
            XCTAssertTrue(SettingsProductionVisibility.isHiddenInProduction(rowID))
        }
    }

    // MARK: - 12. Developer section visible in debug

    func testQA12_DeveloperSectionVisibleInDebug() {
        let state = SettingsPresentationBuilder.build(input: debugInput())

        XCTAssertNotNil(state.developer)
        XCTAssertTrue(state.isDebugOrInternalBuild)
        XCTAssertEqual(state.developer?.rows.map(\.id), [.authDiagnostics, .pipelineTraces, .healthIntelligenceSnapshot, .coachContextInspector, .accountSyncDiagnostics, .accountRestoreDiagnostics])
    }

    // MARK: - 13. No broken coming-soon rows

    func testQA13_ProductionHasNoProhibitedPlaceholderCopy() {
        let state = productionState()
        let titles = allRowTitles(in: state)

        XCTAssertFalse(SettingsProductionVisibility.containsProhibitedPlaceholderCopy(titles))
        XCTAssertTrue(state.visibleRowIDs.contains(.exportData))
        XCTAssertTrue(state.visibleRowIDs.contains(.accountDataStatus))
        XCTAssertTrue(state.visibleRowIDs.contains(.syncStatus))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteLocalDeviceData))
        XCTAssertTrue(state.visibleRowIDs.contains(.healthDataNote))
    }

    // MARK: - 14. No sensitive data logged in analytics

    @MainActor
    func testQA14_AnalyticsPayloadsArePrivacySafe() {
        let analytics = CapturingSettingsAnalyticsLogger()
        let coordinator = SettingsAnalyticsCoordinator(analyticsLogger: analytics)
        coordinator.updateContext(
            unitSystem: .metric,
            themePalette: .oceanBlue,
            integrationState: .connected
        )

        coordinator.logSettingsViewed()
        coordinator.logRowTapped(rowID: .bodyAndStats, sectionType: .preferences)
        coordinator.logBodyStatsViewed()
        coordinator.logPrivacyPolicyTapped(sectionType: .privacyData)
        coordinator.logSupportTapped(topic: .feedback)
        coordinator.logLogoutTapped()

        for entry in analytics.events {
            XCTAssertTrue(SettingsAnalyticsContextBuilder.isPrivacySafe(entry.properties.asParameters()))
        }
    }

    // MARK: - 15. No layout overflow

    func testQA15_LayoutConstantsMeetAccessibilityMinimums() {
        XCTAssertGreaterThanOrEqual(
            SettingsChromeAccessibility.minimumRowTouchTarget,
            FormaTokens.Layout.minTouchTarget
        )
        XCTAssertGreaterThanOrEqual(
            SettingsChromeAccessibility.minimumActionButtonHeight,
            FormaTokens.Layout.minTouchTarget
        )
        XCTAssertGreaterThanOrEqual(SettingsChromeAccessibility.rowTitleLineLimit, 1)
        XCTAssertGreaterThanOrEqual(SettingsChromeAccessibility.statusLineLimit, 1)
        XCTAssertTrue(SettingsRowAccessibilityPolicy.supportsDynamicTypeWrapping)
        XCTAssertTrue(SettingsRowAccessibilityPolicy.supportsLongEmailWrapping)
    }

    // MARK: - Developer route compile-time gate

    func testQA_DeveloperToolsEnabledByAbTest() {
        XCTAssertTrue(FormaBuildConfiguration.includesCompiledDeveloperTools)
        XCTAssertTrue(FormaAbTest.Build.includesDeveloperTools)
    }
}
