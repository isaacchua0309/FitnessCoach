//
//  SettingsAccountDeletionViewModelTests.swift
//  Fitness CoachTests
//
//  Forma — Account deletion confirmation UI state tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDeletionViewModelTests: XCTestCase {

    func testCancelDuringConfirmationResetsIdleState() {
        let viewModel = AccountDeletionViewModel()
        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"

        viewModel.cancelFlow()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertFalse(viewModel.isPerformingDeletion)
        XCTAssertTrue(viewModel.confirmationText.isEmpty)
    }

    func testTypedConfirmationRequiredBeforeDelete() {
        let viewModel = AccountDeletionViewModel()
        viewModel.beginConfirmation(scope: .fullAccount)

        XCTAssertFalse(viewModel.canConfirmDeletion)

        viewModel.confirmationText = "DELETE"
        XCTAssertTrue(viewModel.canConfirmDeletion)
    }

    func testProgressLabelsMatchRequiredCopy() {
        XCTAssertEqual(
            AccountDeletionStatusFormatting.progressLabel(for: .preparing),
            FormaProductCopy.Settings.PrivacyData.deletionProgressPreparing
        )
        XCTAssertEqual(
            AccountDeletionStatusFormatting.progressLabel(for: .deletingRemoteData),
            FormaProductCopy.Settings.PrivacyData.deletionProgressDeletingAccountData
        )
        XCTAssertEqual(
            AccountDeletionStatusFormatting.progressLabel(for: .deletingAuthAccount),
            FormaProductCopy.Settings.PrivacyData.deletionProgressDeletingAccount
        )
        XCTAssertEqual(
            AccountDeletionStatusFormatting.progressLabel(for: .wipingLocalData),
            FormaProductCopy.Settings.PrivacyData.deletionProgressRemovingLocalData
        )
        XCTAssertEqual(
            AccountDeletionStatusFormatting.progressLabel(for: .completed),
            FormaProductCopy.Settings.PrivacyData.deletionProgressCompleted
        )
    }

    func testDeleteAccountCopyIncludesRequiredGuardrails() {
        let presentation = AccountDeletionPresentationBuilder.build(scope: .fullAccount)

        XCTAssertEqual(
            presentation.navigationTitle,
            FormaProductCopy.Settings.PrivacyData.deleteAccountConfirmationTitle
        )
        XCTAssertTrue(
            presentation.consequenceBullets.contains(
                "Deleting your account removes your Forma account and app data stored with your account."
            )
        )
        XCTAssertTrue(presentation.consequenceBullets.contains("This cannot be undone."))
        XCTAssertTrue(
            presentation.consequenceBullets.contains(
                "This does not delete data stored in Apple Health."
            )
        )
        XCTAssertTrue(
            presentation.consequenceBullets.contains("This does not delete your Google account.")
        )
        XCTAssertEqual(
            presentation.confirmActionTitle,
            FormaProductCopy.Settings.PrivacyData.deleteAccountConfirmActionTitle
        )
    }

    func testDeleteLocalDeviceCopyExplainsCloudDataRemains() {
        let presentation = AccountDeletionPresentationBuilder.build(scope: .localDeviceOnly)

        XCTAssertTrue(
            presentation.consequenceBullets.contains {
                $0.contains("cloud account") && $0.contains("stay active")
            }
        )
        XCTAssertTrue(
            presentation.consequenceBullets.contains {
                $0.contains("restored") && $0.contains("sign in again")
            }
        )
        XCTAssertEqual(
            presentation.confirmActionTitle,
            FormaProductCopy.Settings.PrivacyData.deleteLocalDeviceDataConfirmActionTitle
        )
    }

    func testSafeErrorMessageFiltersRawBackendTerms() {
        let summary = AccountDeletionSummary(
            uid: "user",
            scope: .fullAccount,
            status: .failed,
            startedAt: Date(),
            endedAt: Date(),
            remoteProfileDeleted: false,
            remoteDailyLogsDeleted: 0,
            remoteFoodEntriesDeleted: 0,
            remoteWaterEntriesDeleted: 0,
            remoteWeightEntriesDeleted: 0,
            remoteDailyReviewsDeleted: 0,
            remoteHealthSummariesDeleted: false,
            authAccountDeleted: false,
            localProfileDeleted: false,
            localDailyLogsDeleted: 0,
            localFoodEntriesDeleted: 0,
            localWaterEntriesDeleted: 0,
            localWeightEntriesDeleted: 0,
            localDailyReviewsDeleted: 0,
            localCoachMessagesDeleted: 0,
            localTimelineEventsDeleted: 0,
            localHealthCacheDeleted: false,
            localPreferencesDeleted: false,
            pendingMutationsDeleted: 0,
            failureCategory: .remoteDataDeleteFailed,
            userFacingMessage: "Firestore permission_denied for users/abc"
        )

        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionGenericErrorMessage
        )
    }

    func testReauthenticationButtonCopy() {
        let presentation = AccountDeletionPresentationBuilder.build(scope: .fullAccount)
        XCTAssertEqual(
            presentation.reauthenticateTitle,
            "Reauthenticate and continue"
        )
    }
}
