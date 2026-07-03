//
//  HealthSummarySyncError.swift
//  Fitness Coach
//
//  Forma — Errors surfaced by remote Health Summary Sync clients.
//

import Foundation

enum HealthSummarySyncError: Error, Equatable, Sendable {
    case notAuthenticated
    case userIdMismatch
    case invalidDocumentID
    case uploadFailed(collection: String, reason: String)
    case deleteFailed(reason: String)
    case batchWriteFailed(collection: String, reason: String)

    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "Sign in is required before syncing health summaries."
        case .userIdMismatch:
            return "Health summary payload user id does not match the signed-in user."
        case .invalidDocumentID:
            return "Health summary document id is invalid."
        case .uploadFailed(let collection, let reason):
            return "Failed to upload \(collection): \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete remote health summaries: \(reason)"
        case .batchWriteFailed(let collection, let reason):
            return "Failed to commit \(collection) batch write: \(reason)"
        }
    }
}
