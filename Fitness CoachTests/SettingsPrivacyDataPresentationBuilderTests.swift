//
//  SettingsPrivacyDataPresentationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Privacy & Data settings section presentation tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsPrivacyDataPresentationBuilderTests: XCTestCase {

    func testPrivacySectionIncludesStatusAndDeletionRows() {
        let status = SettingsPrivacyDataStatusSnapshot(
            accountConnection: .signedIn(provider: .google),
            lastSuccessfulSyncAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastSuccessfulRestoreAt: Date(timeIntervalSince1970: 1_699_000_000),
            pendingUploadCount: 2,
            isBlockingRestoreActive: false
        )

        let section = SettingsPrivacyDataPresentationBuilder.buildSection(
            input: SettingsPrivacyDataPresentationInput(
                status: status,
                featureAvailability: SettingsFeatureAvailability(
                    isDataExportEnabled: false,
                    isDeleteAccountEnabled: true,
                    isDeleteLocalDeviceDataEnabled: true
                ),
                legalAvailability: .production,
                accountDeletionWiring: SettingsAccountDeletionWiring(
                    featureAvailability: SettingsFeatureAvailability(
                        isDataExportEnabled: false,
                        isDeleteAccountEnabled: true,
                        isDeleteLocalDeviceDataEnabled: true
                    ),
                    hasCoordinator: true
                )
            )
        )

        XCTAssertEqual(section.title, FormaProductCopy.Settings.Hub.privacyDataSectionTitle)
        XCTAssertEqual(
            section.rows.map(\.id),
            [
                .accountDataStatus,
                .syncStatus,
                .deleteLocalDeviceData,
                .deleteAccount,
                .healthDataNote,
                .exportData,
                .privacyPolicy
            ]
        )
        XCTAssertEqual(
            section.rows.first(where: { $0.id == .syncStatus })?.status,
            FormaProductCopy.Settings.PrivacyData.syncStatusPendingCount(2)
        )
    }

    func testExportPlaceholderWhenNotImplemented() {
        XCTAssertFalse(SettingsDataExportCapability.isImplemented)

        let section = SettingsPrivacyDataPresentationBuilder.buildSection(
            input: SettingsPrivacyDataPresentationInput(
                status: .empty,
                featureAvailability: SettingsFeatureAvailability(
                    isDataExportEnabled: false,
                    isDeleteAccountEnabled: true,
                    isDeleteLocalDeviceDataEnabled: true
                ),
                legalAvailability: .production
            )
        )

        let exportRow = section.rows.first(where: { $0.id == .exportData })
        XCTAssertEqual(exportRow?.status, FormaProductCopy.Settings.PrivacyData.exportUnavailableStatus)
        XCTAssertNil(exportRow?.destination)
        XCTAssertFalse(exportRow?.isEnabled ?? true)
    }

    func testAccountStatusPresentationUsesSafeFieldsOnly() {
        let presentation = SettingsPrivacyDataPresentationBuilder.accountStatusPresentation(
            status: SettingsPrivacyDataStatusSnapshot(
                accountConnection: .signedIn(provider: .google),
                lastSuccessfulSyncAt: nil,
                lastSuccessfulRestoreAt: nil,
                pendingUploadCount: 0,
                isBlockingRestoreActive: false
            )
        )

        let values = presentation.rows.map(\.value).joined(separator: " ")
        XCTAssertFalse(values.localizedCaseInsensitiveContains("@"))
        XCTAssertFalse(values.localizedCaseInsensitiveContains("cal"))
        XCTAssertTrue(values.contains(FormaProductCopy.Settings.PrivacyData.accountStatusSignedIn))
    }

    func testHealthNoteExplainsAppleHealthLimits() {
        let presentation = SettingsPrivacyDataPresentationBuilder.healthNotePresentation()
        let body = presentation.bodyParagraphs.joined(separator: " ")
        XCTAssertTrue(body.contains("Apple Health"))
        XCTAssertTrue(body.contains("locally cached"))
    }
}
