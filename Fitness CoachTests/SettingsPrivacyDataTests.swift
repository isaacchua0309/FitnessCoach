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

    func testProductionHidesNonFunctionalExportAndDelete() {
        XCTAssertFalse(SettingsFeatureAvailability.production.isDataExportEnabled)
        XCTAssertFalse(SettingsFeatureAvailability.production.isDeleteDataEnabled)

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

        XCTAssertFalse(state.visibleRowIDs.contains(.exportData))
        XCTAssertFalse(state.visibleRowIDs.contains(.deleteData))
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
                    isDeleteDataEnabled: true
                ),
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false
            )
        )

        XCTAssertTrue(state.visibleRowIDs.contains(.exportData))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteData))
        XCTAssertEqual(state.privacyData.rows.first(where: { $0.id == .exportData })?.destination, .exportData)
        XCTAssertEqual(state.privacyData.rows.first(where: { $0.id == .deleteData })?.destination, .deleteData)
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
        let original = FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL
        defer { FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = original }
        FormaLegalShippingPolicy.shipsInAppLegalDocumentsWithoutPublishedURL = false

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
    }

    func testTermsRowUsesExternalURLWhenPublished() {
        let termsURL = URL(string: "https://forma.app/terms")!
        let availability = SettingsLegalAvailability(
            termsURL: termsURL,
            privacyPolicyURL: nil
        )

        XCTAssertTrue(availability.isTermsAvailable)
        XCTAssertEqual(availability.externalURL(for: .terms), termsURL)
    }

    // MARK: - Delete confirmation

    func testDeleteConfirmationCopyWhenEnabled() {
        let presentation = SettingsDeleteDataPresentationBuilder.build()

        XCTAssertEqual(presentation.confirmationTitle, FormaProductCopy.Settings.PrivacyData.deleteConfirmationTitle)
        XCTAssertTrue(presentation.confirmationMessage.contains("permanently"))
        XCTAssertTrue(presentation.confirmationMessage.contains("cannot be undone"))
        XCTAssertEqual(presentation.confirmActionTitle, FormaProductCopy.Settings.PrivacyData.deleteConfirmActionTitle)
    }

    func testDeleteActionDoesNotRunUntilImplemented() {
        XCTAssertFalse(SettingsDataDeletionCapability.isImplemented)
        XCTAssertEqual(SettingsDeleteDataActionHandler.perform(), .notImplemented)
    }

    func testExportActionDoesNotRunUntilImplemented() {
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
}
