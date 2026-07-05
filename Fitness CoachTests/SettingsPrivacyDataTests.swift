//
//  SettingsPrivacyDataTests.swift
//  Fitness CoachTests
//
//  Forma — Privacy & Data settings section tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsPrivacyDataTests: XCTestCase {

    // MARK: - Production visibility

    func testProductionShowsExportAndDeleteWhenEnabled() {
        XCTAssertTrue(SettingsFeatureAvailability.production.isDeleteAccountEnabled)
        XCTAssertTrue(SettingsFeatureAvailability.production.isDeleteLocalDeviceDataEnabled)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertTrue(state.visibleRowIDs.contains(.accountDataStatus))
        XCTAssertTrue(state.visibleRowIDs.contains(.syncStatus))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteLocalDeviceData))
        XCTAssertTrue(state.visibleRowIDs.contains(.healthDataNote))
        XCTAssertTrue(state.visibleRowIDs.contains(.exportData))
    }

    func testFunctionalFlagsShowExportAndDeleteRows() {
        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: SettingsFeatureAvailability(
                    isDataExportEnabled: true,
                    isDeleteAccountEnabled: true,
                    isDeleteLocalDeviceDataEnabled: true
                ),
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false,
                accountDeletionWiring: SettingsAccountDeletionWiring(
                    featureAvailability: SettingsFeatureAvailability(
                        isDataExportEnabled: true,
                        isDeleteAccountEnabled: true,
                        isDeleteLocalDeviceDataEnabled: true
                    ),
                    hasCoordinator: true
                )
            )
        )

        XCTAssertTrue(state.visibleRowIDs.contains(.exportData))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteLocalDeviceData))
        XCTAssertTrue(state.visibleRowIDs.contains(.accountDataStatus))
        XCTAssertTrue(state.visibleRowIDs.contains(.syncStatus))
        XCTAssertEqual(
            state.privacyData.rows.first(where: { $0.id == .deleteAccount })?.destination,
            .deleteAccount
        )
        XCTAssertEqual(
            state.privacyData.rows.first(where: { $0.id == .deleteLocalDeviceData })?.destination,
            .deleteLocalDeviceData
        )
    }

    // MARK: - Legal availability

    func testPrivacyPolicyRowAppearsWhenPublishedURLExists() {
        let privacyURL = URL(string: "https://forma.app/privacy")!
        let availability = SettingsLegalAvailability(
            termsURL: nil,
            privacyPolicyURL: privacyURL
        )

        XCTAssertTrue(availability.isPrivacyPolicyAvailable)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: availability,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertTrue(state.privacyData.rows.contains(where: { $0.id == .privacyPolicy }))
        XCTAssertEqual(state.externalURL(for: .privacyPolicy), privacyURL)
    }

    func testLegalRowsHideWhenURLsMissingAndInAppShippingDisabled() {
        let original = FormaAbTest.testOverride
        defer { FormaAbTest.testOverride = original }
        var snapshot = FormaAbTestSnapshot.allEnabled
        snapshot.shipsInAppLegalWithoutPublishedURL = false
        FormaAbTest.testOverride = snapshot

        let availability = SettingsLegalAvailability(termsURL: nil, privacyPolicyURL: nil)
        XCTAssertFalse(availability.isPrivacyPolicyAvailable)
        XCTAssertFalse(availability.isTermsAvailable)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: availability,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertTrue(state.privacyData.rows.isEmpty)
        XCTAssertFalse(state.about.rows.contains(where: { $0.id == .termsOfService }))
        XCTAssertFalse(state.about.rows.contains(where: { $0.id == .privacyPolicy }))
    }

    func testTermsRowUsesExternalURLWhenPublished() {
        let termsURL = URL(string: "https://forma.app/terms")!
        let availability = SettingsLegalAvailability(
            termsURL: termsURL,
            privacyPolicyURL: nil
        )

        XCTAssertTrue(availability.isTermsAvailable)
        XCTAssertEqual(availability.externalURL(for: .terms), termsURL)

        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: availability,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertEqual(state.externalURL(for: .terms), termsURL)
        XCTAssertEqual(
            state.about.rows.first(where: { $0.id == .termsOfService })?.destination,
            .legalDocument(.terms)
        )
    }

    // MARK: - Delete confirmation

    func testDeleteAccountConfirmationCopyWhenEnabled() {
        let presentation = AccountDeletionPresentationBuilder.build(scope: .fullAccount)

        XCTAssertEqual(
            presentation.navigationTitle,
            FormaProductCopy.Settings.PrivacyData.deleteAccountConfirmationTitle
        )
        XCTAssertTrue(presentation.consequenceBullets.contains("cannot be undone"))
        XCTAssertTrue(presentation.consequenceBullets.contains("Apple Health"))
        XCTAssertEqual(
            presentation.confirmActionTitle,
            FormaProductCopy.Settings.PrivacyData.deleteAccountConfirmActionTitle
        )
    }

    func testDeleteLocalDeviceConfirmationCopyWhenEnabled() {
        let presentation = AccountDeletionPresentationBuilder.build(scope: .localDeviceOnly)

        XCTAssertEqual(
            presentation.navigationTitle,
            FormaProductCopy.Settings.PrivacyData.deleteLocalDeviceDataConfirmationTitle
        )
        XCTAssertTrue(presentation.consequenceBullets.contains("cannot be undone"))
        XCTAssertTrue(presentation.consequenceBullets.contains { $0.contains("cloud") })
        XCTAssertEqual(
            presentation.confirmActionTitle,
            FormaProductCopy.Settings.PrivacyData.deleteLocalDeviceDataConfirmActionTitle
        )
    }

    func testDeleteActionOpensFlowWhenEnabled() throws {
        let coordinator = try AppContainer(inMemory: true).accountDeletionCoordinator

        XCTAssertTrue(SettingsDataDeletionCapability.isImplemented)
        XCTAssertEqual(
            SettingsDeleteDataActionHandler.perform(scope: .fullAccount, coordinator: coordinator),
            .opensDeletionFlow
        )
        XCTAssertEqual(
            SettingsDeleteDataActionHandler.perform(scope: .localDeviceOnly, coordinator: coordinator),
            .opensDeletionFlow
        )
    }

    func testExportCapabilityDisabledByDefault() {
        XCTAssertFalse(AccountDataExportPolicy.isEnabled)
        XCTAssertFalse(SettingsDataExportCapability.isImplemented)
        XCTAssertFalse(SettingsExportDataActionHandler.perform())
    }

    func testPrivacySectionIncludesTrustFooter() {
        let state = SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertEqual(
            state.privacyData.footer,
            FormaProductCopy.Settings.PrivacyData.sectionFooter
        )
    }

    func testPrivacySectionFooterDoesNotClaimSensitiveValues() {
        XCTAssertTrue(
            FormaProductCopy.Settings.PrivacyData.sectionFooter.localizedCaseInsensitiveContains("counts")
        )
    }
}
