//
//  AccountRestoreViewModelTests.swift
//  Fitness CoachTests
//
//  Forma — Account restore UI phase and view-model tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountRestoreViewModelTests: XCTestCase {

    private var container: AppContainer!
    private var viewModel: AccountRestoreViewModel!

    override func setUp() async throws {
        container = try AppContainer(inMemory: true)
        viewModel = AccountRestoreViewModel(container: container)
    }

    override func tearDown() {
        viewModel = nil
        container = nil
        super.tearDown()
    }

    func testCheckingStateShowsCheckingCopy() {
        viewModel.applyTestingState(phase: .checkingAccount)

        XCTAssertEqual(viewModel.progressMessage, FormaProductCopy.AccountRestore.Progress.checkingAccount)
        XCTAssertNil(viewModel.title)
        XCTAssertFalse(viewModel.showsPrimaryAction)
    }

    func testRestoringProfileStateShowsPlanCopy() {
        viewModel.applyTestingState(phase: .restoringProfile)

        XCTAssertEqual(viewModel.progressMessage, FormaProductCopy.AccountRestore.Progress.restoringProfile)
        XCTAssertFalse(viewModel.showsPrimaryAction)
    }

    func testRestoringRecentDataStateShowsLogsCopy() {
        viewModel.applyTestingState(phase: .restoringRecentLogs)

        XCTAssertEqual(viewModel.progressMessage, FormaProductCopy.AccountRestore.Progress.restoringRecentLogs)
        XCTAssertFalse(viewModel.showsPrimaryAction)
    }

    func testPartialStateAllowsContinue() {
        let summary = RestoreAwareTestSupport.makeRestoreSummary(status: .partial)
        viewModel.applyTestingState(phase: .partialContinue, summary: summary)

        XCTAssertTrue(viewModel.showsPrimaryAction)
        XCTAssertEqual(viewModel.primaryActionTitle, FormaProductCopy.AccountRestore.Partial.continueCTA)
        XCTAssertEqual(viewModel.title, FormaProductCopy.AccountRestore.Partial.title)
    }

    func testOfflineStateAllowsRetry() {
        let summary = RestoreAwareTestSupport.makeRestoreSummary(status: .offline)
        viewModel.applyTestingState(phase: .offlineContinue, summary: summary)

        XCTAssertTrue(viewModel.showsPrimaryAction)
        XCTAssertTrue(viewModel.showsSecondaryRetryAction)
        XCTAssertEqual(viewModel.title, FormaProductCopy.AccountRestore.Offline.title)
    }

    func testFailedStateShowsSafeMessage() {
        let summary = AccountRestoreSummary(
            uid: RestoreAwareTestSupport.ownerUID,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .failed,
            startedAt: ProfileFixtures.referenceDate,
            endedAt: ProfileFixtures.referenceDate,
            profileRestored: false,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            isPartial: false,
            userFacingMessage: nil
        )
        viewModel.applyTestingState(phase: .failed, summary: summary)

        XCTAssertEqual(viewModel.progressMessage, FormaProductCopy.AccountRestore.Failed.body)
        XCTAssertEqual(viewModel.title, FormaProductCopy.AccountRestore.Failed.title)
        XCTAssertFalse(viewModel.progressMessage.contains("chicken"))
    }

    func testRetryCallsCoordinator() async {
        let expectation = expectation(description: "retry handler called")
        var retriedUID: String?
        viewModel.applyTestingState(
            phase: .offlineContinue,
            summary: RestoreAwareTestSupport.makeRestoreSummary(status: .offline)
        )
        viewModel.testingRetryHandler = { uid in
            retriedUID = uid
            expectation.fulfill()
            return RestoreAwareTestSupport.makeRestoreSummary(status: .completed)
        }

        viewModel.retry()

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertEqual(retriedUID, RestoreAwareTestSupport.ownerUID)
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func testUIPhaseMapsRestoreStatuses() {
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .checking), .checkingAccount)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .restoringProfile), .restoringProfile)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .restoringRecentData), .restoringRecentLogs)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .partial), .partialContinue)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .offline), .offlineContinue)
        XCTAssertEqual(AccountRestoreUIPhase(restoreStatus: .failed), .failed)
    }
}
