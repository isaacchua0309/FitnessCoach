//
//  AccountRestoreViewModelTests.swift
//  Fitness CoachTests
//
//  Forma — Account restore UI phase mapping tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

final class AccountRestoreViewModelTests: XCTestCase {

    func testUIPhaseMapsRestoreStatuses() {
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .checking), .checkingAccount)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .restoringProfile), .restoringProfile)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .restoringRecentData), .restoringRecentLogs)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .restoringWeightHistory), .restoringWeightHistory)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .rebuildingLocalViews), .preparingDashboard)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .partial), .partialContinue)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .offline), .offlineContinue)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .failed), .failed)
    }

    func testProgressCopyUsesUserFacingStrings() {
        XCTAssertEqual(
            AccountRestoreUIPhase.checkingAccount.progressMessage,
            FormaProductCopy.AccountRestore.Progress.checkingAccount
        )
        XCTAssertEqual(
            AccountRestoreUIPhase.restoringRecentLogs.progressMessage,
            FormaProductCopy.AccountRestore.Progress.restoringRecentLogs
        )
        XCTAssertEqual(
            AccountRestoreUIPhase.partialContinue.progressMessage,
            FormaProductCopy.AccountRestore.Partial.body
        )
        XCTAssertEqual(
            AccountRestoreUIPhase.offlineContinue.progressMessage,
            FormaProductCopy.AccountRestore.Offline.body
        )
        XCTAssertEqual(
            AccountRestoreUIPhase.failed.progressMessage,
            FormaProductCopy.AccountRestore.Failed.body
        )
    }

    func testTerminalPhasesExposeActions() {
        XCTAssertTrue(AccountRestoreUIPhase.partialContinue.showsPrimaryAction)
        XCTAssertTrue(AccountRestoreUIPhase.offlineContinue.showsPrimaryAction)
        XCTAssertTrue(AccountRestoreUIPhase.failed.showsPrimaryAction)
        XCTAssertTrue(AccountRestoreUIPhase.failed.showsSignOutAction)
        XCTAssertFalse(AccountRestoreUIPhase.restoringProfile.showsPrimaryAction)
    }
}

private extension AccountRestoreUIPhase {
    var progressMessage: String {
        switch self {
        case .checkingAccount:
            return FormaProductCopy.AccountRestore.Progress.checkingAccount
        case .restoringProfile:
            return FormaProductCopy.AccountRestore.Progress.restoringProfile
        case .restoringRecentLogs:
            return FormaProductCopy.AccountRestore.Progress.restoringRecentLogs
        case .restoringWeightHistory:
            return FormaProductCopy.AccountRestore.Progress.restoringWeightHistory
        case .preparingDashboard:
            return FormaProductCopy.AccountRestore.Progress.preparingDashboard
        case .completed:
            return FormaProductCopy.AccountRestore.Completed.message
        case .partialContinue:
            return FormaProductCopy.AccountRestore.Partial.body
        case .offlineContinue:
            return FormaProductCopy.AccountRestore.Offline.body
        case .failed:
            return FormaProductCopy.AccountRestore.Failed.body
        }
    }
}
