//
//  InMemoryAccountAuthDeleting.swift
//  Fitness Coach
//
//  In-memory account auth deletion fake for unit tests (no Firebase).
//

import Foundation

@MainActor
final class InMemoryAccountAuthDeleting: AccountAuthDeleting {

    private(set) var deleteCallCount = 0
    private(set) var reauthCallCount = 0

    var configuredDeleteError: AccountAuthDeletionError?
    var configuredReauthError: AccountAuthDeletionError?
    var onDeleteCalled: (() -> Void)?
    var onReauthCalled: (() -> Void)?

    func deleteCurrentAuthAccount() async throws {
        deleteCallCount += 1
        onDeleteCalled?()
        if let configuredDeleteError {
            throw configuredDeleteError
        }
    }

    func reauthenticateForAccountDeletion() async throws {
        reauthCallCount += 1
        onReauthCalled?()
        if let configuredReauthError {
            throw configuredReauthError
        }
    }

    func reset() {
        deleteCallCount = 0
        reauthCallCount = 0
        configuredDeleteError = nil
        configuredReauthError = nil
    }
}
