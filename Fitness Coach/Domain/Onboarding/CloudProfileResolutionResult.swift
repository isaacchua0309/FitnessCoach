//
//  CloudProfileResolutionResult.swift
//  Fitness Coach
//
//  Forma — Read-only cloud profile lookup result (missing ≠ failed).
//

import Foundation

enum CloudProfileResolutionResult: Sendable {
    case found(CloudUserProfileDocument)
    case missing
    case failed(CloudProfileResolutionFailure)
}

/// Testable, sendable wrapper around a cloud fetch error.
struct CloudProfileResolutionFailure: Error, Equatable, Sendable {
    let localizedDescription: String
    let domain: String
    let code: Int

    init(_ error: Error) {
        let nsError = error as NSError
        localizedDescription = error.localizedDescription
        domain = nsError.domain
        code = nsError.code
    }
}

extension CloudProfileResolutionResult {

    /// Maps into the pure ownership resolver's cloud lookup enum (summary only).
    var ownershipLookupResult: CloudProfileLookupResult {
        switch self {
        case .found(let document):
            return .found(CloudProfileSummary(updatedAt: document.updatedAt))
        case .missing:
            return .missing
        case .failed:
            return .failed
        }
    }

    var isMissing: Bool {
        if case .missing = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
