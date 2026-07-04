//
//  AccountAuthDeletionTests.swift
//  Fitness CoachTests
//
//  Account auth deletion policy, error classification, and in-memory fakes.
//

import XCTest
@testable import Fitness_Coach

final class AccountAuthDeletionTests: XCTestCase {

    func testDeleteAuthMapsRecentLoginRequired() {
        let error = NSError(
            domain: AuthAccountDeletionErrorClassifier.firebaseAuthErrorDomain,
            code: AuthAccountDeletionErrorClassifier.requiresRecentLoginCode
        )

        XCTAssertEqual(
            AuthAccountDeletionErrorClassifier.classify(error),
            .reauthenticationRequired
        )
    }

    func testReauthCancellationDoesNotLeaveLoadingState() async {
        let authDeleting = await MainActor.run { InMemoryAccountAuthDeleting() }
        await MainActor.run {
            authDeleting.configuredReauthError = .cancelled
        }

        do {
            try await authDeleting.reauthenticateForAccountDeletion()
            XCTFail("Expected cancelled")
        } catch {
            await MainActor.run {
                XCTAssertEqual(error as? AccountAuthDeletionError, .cancelled)
                XCTAssertEqual(authDeleting.reauthCallCount, 1)
                XCTAssertEqual(authDeleting.deleteCallCount, 0)
            }
        }
    }

    func testUnsupportedProviderShowsSafeError() async {
        let authDeleting = await MainActor.run { InMemoryAccountAuthDeleting() }
        await MainActor.run {
            authDeleting.configuredDeleteError = .providerMismatch
        }

        do {
            try await authDeleting.deleteCurrentAuthAccount()
            XCTFail("Expected providerMismatch")
        } catch {
            await MainActor.run {
                XCTAssertEqual(error as? AccountAuthDeletionError, .providerMismatch)
            }
        }

        XCTAssertEqual(
            AuthAccountDeletionPolicy.providerEligibility(isGoogleUser: false),
            .unsupported
        )
        XCTAssertEqual(
            AuthAccountDeletionPolicy.unsupportedProviderError(),
            .providerMismatch
        )
    }

    func testGoogleUserIsEligibleForAccountDeletion() {
        XCTAssertEqual(
            AuthAccountDeletionPolicy.providerEligibility(isGoogleUser: true),
            .google
        )
    }

    func testClassifierMapsGoogleCancellationToCancelled() {
        let error = NSError(
            domain: AuthSignInErrorClassifier.googleSignInErrorDomain,
            code: AuthSignInErrorClassifier.canceledErrorCode
        )

        XCTAssertEqual(
            AuthAccountDeletionErrorClassifier.classify(error),
            .cancelled
        )
    }

    func testClassifierMapsOfflineURLErrorToNetwork() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: URLError.notConnectedToInternet.rawValue
        )

        XCTAssertEqual(
            AuthAccountDeletionErrorClassifier.classify(error),
            .network
        )
    }

    @MainActor
    func testInMemoryFakeCanSimulateReauthenticationRequiredThenRecovery() async {
        let authDeleting = InMemoryAccountAuthDeleting()

        authDeleting.configuredDeleteError = .reauthenticationRequired

        do {
            try await authDeleting.deleteCurrentAuthAccount()
            XCTFail("Expected reauthenticationRequired")
        } catch {
            XCTAssertEqual(error as? AccountAuthDeletionError, .reauthenticationRequired)
        }

        authDeleting.configuredDeleteError = nil
        authDeleting.configuredReauthError = nil

        try await authDeleting.reauthenticateForAccountDeletion()
        try await authDeleting.deleteCurrentAuthAccount()

        XCTAssertEqual(authDeleting.reauthCallCount, 1)
        XCTAssertEqual(authDeleting.deleteCallCount, 2)
    }
}
