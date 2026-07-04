//
//  PrivacyDataSettingsTests.swift
//  Fitness CoachTests
//
//  Forma — Privacy & Data settings section tests (Phase 6).
//

import XCTest
@testable import Fitness_Coach

final class PrivacyDataSettingsTests: XCTestCase {

    func testPrivacySectionShowsAccountAndSyncStatusRows() {
        let section = makeProductionPrivacySection()

        XCTAssertTrue(section.rows.contains(where: { $0.id == .accountDataStatus }))
        XCTAssertTrue(section.rows.contains(where: { $0.id == .syncStatus }))
        XCTAssertTrue(section.rows.contains(where: { $0.id == .healthDataNote }))
    }

    func testDeleteActionsRequireImplementedCapability() {
        XCTAssertTrue(SettingsDataDeletionCapability.isImplemented)
        XCTAssertEqual(SettingsDeleteDataActionHandler.perform(scope: .fullAccount), .opensDeletionFlow)
        XCTAssertEqual(SettingsDeleteDataActionHandler.perform(scope: .localDeviceOnly), .opensDeletionFlow)
    }

    func testExportDisabledByDefaultShowsPlaceholderBehavior() {
        XCTAssertFalse(AccountDataExportPolicy.isEnabled)
        XCTAssertFalse(SettingsDataExportCapability.isImplemented)
        XCTAssertFalse(SettingsExportDataActionHandler.perform())

        let section = makeProductionPrivacySection()
        let exportRow = section.rows.first(where: { $0.id == .exportData })
        XCTAssertNotNil(exportRow)
        XCTAssertFalse(exportRow?.isEnabled ?? true)
        XCTAssertNil(exportRow?.destination)
    }

    @MainActor
    func testDeleteAccountConfirmationCannotProceedWithoutTypedPhrase() {
        let viewModel = AccountDeletionViewModel()
        viewModel.beginConfirmation(scope: .fullAccount)

        XCTAssertFalse(viewModel.canConfirmDeletion)
        XCTAssertTrue(AccountDeletionPolicy.requiresTypedConfirmation)
        XCTAssertEqual(AccountDeletionPolicy.confirmationPhrase, "DELETE")
    }

    func testPrivacyStatusSnapshotExcludesSensitivePayloads() {
        let snapshot = SettingsPrivacyDataStatusSnapshot(
            accountConnection: .signedIn(provider: .google),
            lastSuccessfulSyncAt: ProfileTestFixtures.referenceDate,
            lastSuccessfulRestoreAt: ProfileTestFixtures.referenceDate,
            pendingUploadCount: 2,
            isBlockingRestoreActive: false
        )

        let presentation = SettingsPrivacyDataPresentationBuilder.accountStatusPresentation(status: snapshot)
        let serialized = presentation.rows.map(\.value).joined(separator: " ")

        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("firebase"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("uid:"))
        XCTAssertFalse(presentation.rows.isEmpty)
    }

    func testPrivacySectionFooterUsesCountsNotRawValues() {
        XCTAssertTrue(
            FormaProductCopy.Settings.PrivacyData.sectionFooter.localizedCaseInsensitiveContains("counts")
        )
    }

    func testProductionShowsDeleteRowsWhenEnabled() {
        XCTAssertTrue(SettingsFeatureAvailability.production.isDeleteAccountEnabled)
        XCTAssertTrue(SettingsFeatureAvailability.production.isDeleteLocalDeviceDataEnabled)

        let state = makeProductionSettingsState()
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteLocalDeviceData))
    }

    private func makeProductionPrivacySection() -> SettingsPrivacyDataSectionState {
        SettingsPrivacyDataPresentationBuilder.buildSection(
            input: SettingsPrivacyDataPresentationInput(
                status: .empty,
                featureAvailability: .production,
                legalAvailability: .production
            )
        )
    }

    private func makeProductionSettingsState() -> SettingsPresentationState {
        SettingsPresentationBuilder.build(
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
    }
}
