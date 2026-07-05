//
//  SettingsAccountDeletionWiringTests.swift
//  Fitness CoachTests
//
//  Forma — Settings account deletion coordinator wiring regressions.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class SettingsAccountDeletionWiringTests: XCTestCase {

    private var coordinator: AccountDeletionCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        coordinator = try AppContainer(inMemory: true).accountDeletionCoordinator
    }

    func testDeleteActionOpensFlowWhenCoordinatorPresent() {
        XCTAssertEqual(
            SettingsDeleteDataActionHandler.perform(scope: .fullAccount, coordinator: coordinator),
            .opensDeletionFlow
        )
        XCTAssertEqual(
            SettingsDeleteDataActionHandler.perform(scope: .localDeviceOnly, coordinator: coordinator),
            .opensDeletionFlow
        )
    }

    func testDeleteActionUnavailableWhenCoordinatorMissing() {
        XCTAssertEqual(
            SettingsDeleteDataActionHandler.perform(scope: .fullAccount, coordinator: nil),
            .unavailable
        )
        XCTAssertEqual(
            SettingsDeleteDataActionHandler.perform(scope: .localDeviceOnly, coordinator: nil),
            .unavailable
        )
    }

    func testWiredPresentationShowsActionableDeleteRows() {
        let state = makeSettingsState(hasCoordinator: true)

        let deleteAccountRow = state.privacyData.rows.first(where: { $0.id == .deleteAccount })
        let deleteLocalRow = state.privacyData.rows.first(where: { $0.id == .deleteLocalDeviceData })

        XCTAssertEqual(deleteAccountRow?.destination, .deleteAccount)
        XCTAssertTrue(deleteAccountRow?.isEnabled ?? false)
        XCTAssertEqual(deleteLocalRow?.destination, .deleteLocalDeviceData)
        XCTAssertTrue(deleteLocalRow?.isEnabled ?? false)
    }

    func testMissingCoordinatorShowsDisabledDeleteRowsWithUnavailableStatus() {
        let state = makeSettingsState(hasCoordinator: false)

        let deleteAccountRow = state.privacyData.rows.first(where: { $0.id == .deleteAccount })
        let deleteLocalRow = state.privacyData.rows.first(where: { $0.id == .deleteLocalDeviceData })

        XCTAssertTrue(state.visibleRowIDs.contains(.deleteAccount))
        XCTAssertTrue(state.visibleRowIDs.contains(.deleteLocalDeviceData))
        XCTAssertNil(deleteAccountRow?.destination)
        XCTAssertNil(deleteLocalRow?.destination)
        XCTAssertFalse(deleteAccountRow?.isEnabled ?? true)
        XCTAssertFalse(deleteLocalRow?.isEnabled ?? true)
        XCTAssertEqual(
            deleteAccountRow?.status,
            FormaProductCopy.Settings.PrivacyData.deletionCoordinatorUnavailableStatus
        )
        XCTAssertEqual(
            deleteLocalRow?.status,
            FormaProductCopy.Settings.PrivacyData.deletionCoordinatorUnavailableStatus
        )
    }

    func testProductionAppContainerProvidesAccountDeletionCoordinator() throws {
        let container = try AppContainer(inMemory: true)
        XCTAssertNotNil(container.accountDeletionCoordinator)
    }

    func testAuthGateWiresAccountDeletionRouterBeforeDeletionCanRun() throws {
        let container = try AppContainer(inMemory: true)
        let authGateCoordinator = AuthGateCoordinator(container: container)

        XCTAssertNil(container.accountDeletionRouter.onFullAccountDeletion)
        XCTAssertNil(container.accountDeletionRouter.onLocalDeviceOnlyWipe)

        authGateCoordinator.wireAccountDeletionRouter()

        XCTAssertNotNil(container.accountDeletionRouter.onFullAccountDeletion)
        XCTAssertNotNil(container.accountDeletionRouter.onLocalDeviceOnlyWipe)
    }

    func testViewModelDoesNotStartDeletionWithoutCoordinator() {
        let viewModel = AccountDeletionViewModel()
        viewModel.configure(coordinator: nil)
        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()

        guard case .finished(_, let summary) = viewModel.phase else {
            return XCTFail("Expected finished unavailable summary without coordinator.")
        }

        XCTAssertFalse(summary.isSuccessful)
        XCTAssertEqual(
            summary.userFacingMessage,
            FormaProductCopy.Settings.PrivacyData.deletionFlowUnavailableMessage
        )
    }

    private func makeSettingsState(hasCoordinator: Bool) -> SettingsPresentationState {
        SettingsPresentationBuilder.build(
            input: SettingsPresentationInput(
                integrationState: .connected,
                unitSystem: .metric,
                themePalette: .oceanBlue,
                appVersion: "1.0",
                featureAvailability: .production,
                legalAvailability: .production,
                supportConfiguration: .production,
                isDebugOrInternalBuild: false,
                accountDeletionWiring: SettingsAccountDeletionWiring(
                    featureAvailability: .production,
                    hasCoordinator: hasCoordinator
                )
            )
        )
    }
}
