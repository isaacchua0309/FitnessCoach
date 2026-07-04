//
//  AccountAuthDeletionTests.swift
//  Fitness CoachTests
//
//  Account auth deletion policy, error classification, and in-memory fakes.
//

import XCTest
@testable import Fitness_Coach

final class AccountAuthDeletionTests: XCTestCase {

    // MARK: - Policy

    func testGoogleUserIsEligibleForAccountDeletion() {
        XCTAssertEqual(
            AuthAccountDeletionPolicy.providerEligibility(isGoogleUser: true),
            .google
        )
    }

    func testNonGoogleUserIsUnsupportedForAccountDeletion() {
        XCTAssertEqual(
            AuthAccountDeletionPolicy.providerEligibility(isGoogleUser: false),
            .unsupported
        )
        XCTAssertEqual(
            AuthAccountDeletionPolicy.unsupportedProviderError(),
            .providerMismatch
        )
    }

    // MARK: - Error classification

    func testClassifierMapsRequiresRecentLoginToReauthenticationRequired() {
        let error = NSError(
            domain: AuthAccountDeletionErrorClassifier.firebaseAuthErrorDomain,
            code: AuthAccountDeletionErrorClassifier.requiresRecentLoginCode
        )

        XCTAssertEqual(
            AuthAccountDeletionErrorClassifier.classify(error),
            .reauthenticationRequired
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

    // MARK: - In-memory fake

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

    @MainActor
    func testInMemoryFakePropagatesCancelledReauthWithoutDeleting() async {
        let authDeleting = InMemoryAccountAuthDeleting()
        authDeleting.configuredReauthError = .cancelled

        do {
            try await authDeleting.reauthenticateForAccountDeletion()
            XCTFail("Expected cancelled")
        } catch {
            XCTAssertEqual(error as? AccountAuthDeletionError, .cancelled)
        }

        authDeleting.configuredDeleteError = nil

        try await authDeleting.deleteCurrentAuthAccount()
        XCTAssertEqual(authDeleting.reauthCallCount, 1)
        XCTAssertEqual(authDeleting.deleteCallCount, 1)
    }

    @MainActor
    func testInMemoryFakeCanSimulateProviderMismatch() async {
        let authDeleting = InMemoryAccountAuthDeleting()
        authDeleting.configuredDeleteError = .providerMismatch

        do {
            try await authDeleting.deleteCurrentAuthAccount()
            XCTFail("Expected providerMismatch")
        } catch {
            XCTAssertEqual(error as? AccountAuthDeletionError, .providerMismatch)
        }
    }
}
